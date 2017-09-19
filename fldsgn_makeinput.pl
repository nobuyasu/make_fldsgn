#!/usr/bin/perl -w

use lib "$ENV{'HOME'}/scripts/fldsgn";
use lib "$ENV{'HOME'}/perllib";

use READ_INPUTS;
use GET_SSPTNS;
use GET_SSMAP;
use WRITE_BBSKEL;
use WRITE_XML;

###########################################################################
use App::Options(

  values => \%optn,

  option => {

    input => {
      type => 'string',
      required => 1,
    },
    dir => {
	    type => 'string',
	    required => 1,
    },
    pdb => {
      type => 'string',
      default => '/pdb/input.pdb',
    },
    threqdseq => {
      type => 'string',
      required => 0,
    },
    njobs => {
      type => 'integer',
      default => 10,
    },
    npara => {
      type => 'integer',
      default => 1,
    },
    nstruct => {
      type => 'integer',
      default => 500,
    },
    jobtype => {
      type => 'string',
      default => 'small',
    },
    queue => {
      type => 'string',
      default => 'PF',
    },

          #force => {
          #  type => 'bool',
          #  description => 'remove directory and create new directory',
          #  default => 0,
          #},

},

);

my $PWD = `pwd`; chomp $PWD;
my $HOME = $ENV{'HOME'};

# intput pdb setup
my $h = $optn{pdb};
$h =~ s/^\.//;
my $INPUT_PDB = $PWD.$h;

# rosetta
my $EXEC = $HOME."/rosetta/mini/bin/rosetta_scripts.static.linuxiccrelease";
#my $EXEC = "/home/nobuyasu/rosetta/mini/bin/rosetta_scripts.linuxgccrelease";
#my $ARGS = " -database ${HOME}/rosetta/rosetta_database -s $INPUT_PDB -nstruct $optn{nstruct} -frags::vall_size 200000";
my $ARGS = " -database ${HOME}/rosetta/rosetta_database -s $INPUT_PDB -nstruct $optn{nstruct} ";
my $average = "$HOME/rosetta/Rosetta/main/source/bin/ave_structr.linuxgccrelease -database $HOME/rosetta/Rosetta/main/database -hbonds_strong ";
my $analyze = "$HOME/rosetta/mini/bin/analyze_r2x3.linuxiccrelease -database $HOME/rosetta/rosetta_database -nooutput ";
my $anal_R_1 = "R --file=$HOME/paper/3_2017/scripts/parallel_beta.geom.R";
my $anal_R_2 = "R --file=$HOME/paper/3_2017/scripts/parallel_beta.hbond.R";

# make directories
if( -e "$optn{dir}" ) {

  print "There is a directory that has the same name. \n";
  print "Are you sure ?. \n";
  $in = <STDIN>;
  chomp $in;
  if($in ne "yes"){
    die("bye bye\n");
  }
  system( "rm -fR $optn{dir} ");
  #if( $optn{force} ) {
  #  print "The directory $optn{dir} will be removed. \n";
  #  print "Are you sure ?. \n";
  #  $in = <STDIN>;
  #  chomp $in;
  #  if($in ne "yes"){
  #    die("bye bye\n");
  #  }
  #  system( "rm -fR $optn{dir} ");
  #}
}
if( !-e "$optn{dir}/inputs" ) {
  system( "mkdir -p $optn{dir}/inputs");
}
if( !-e "$optn{dir}/data" ) {
  system( "mkdir -p $optn{dir}/data");
}

my $outdir = $PWD."/".$optn{dir};

open( INFO, ">>${outdir}/info" ) || die( "cannot make info\n" );
print INFO "# pdb=$optn{pdb} input=$optn{input} nstruct=$optn{nstruct} njobs=$optn{njobs} \n";

opendir( DIR, "$optn{dir}/data" ) || die("cannot open $optn{dir}/data \n");
my $maxdir = 0;
my @files = readdir(DIR);
foreach my $f ( @files ) {
  if( $f =~ m/[0-9]/ || $f =~ m/[1-9][0-9]/ ) {
    if( $maxdir < $f ) {
      $maxdir = $f;
    }
  }
}
close(DIR);


###########################################################################
##  read input
###########################################################################
my $readpre = READ_INPUTS->new;
$readpre->read( $optn{input} );

open( INP2, ">>${outdir}/build.inp" ) || die( "cannot make build.inp\n" );
$readpre->dump( *INP2 );
if ( defined( $optn{threadseq} ) ) {

  if( !-e $optn{threadseq} ) {
    die( "No $optn{threadseq} \n");
  }

  my $threadseq = $optn{threadseq};
  $threadseq = `readlink -f $threadseq`; chomp $threadseq;

  my $p = "";
  my @mover_sets = @{$readpre->{mover_sets}};
  for ( my $ii=0; $ii<=$#mover_sets; $ii++ ) {
    my ( $mode, $ssl ) = split( "_", $mover_sets[$ii] );
    if ( $mode =~ m/THREAD/ ) {
      $p = $p."\"${threadseq}\",";
    } else {
      $p = $p."\"\"\,";
    }
  }

  print INP2 "\nEXTRA_FILES = ( ";
  chop $p;
  print INP2 "$p )\n";

}
close( INP2 );

my $read_input = READ_INPUTS->new;
$read_input->read( "${outdir}/build.inp" );

###########################################################################
##  read ss_patterns
###########################################################################
my %ss_patterns = %{$read_input->{ss_patterns}};

my %ssptn;
my %instructions;
my @all_ssptn;
my $get_ssptn = GET_SSPTNS->new;
foreach my $ssp ( keys %ss_patterns ) {

    my @ssptn = @{$ss_patterns{$ssp}};
    $ssptn->{$ssp} = $get_ssptn->read( \@ssptn );
    $instructions->{$ssp}  = $get_ssptn->{inst};
    push( @all_ssptn, $ssptn->{$ssp} );

}

# check consistency for number of sspatterns
for( my $ii=1; $ii<=$#all_ssptn; $ii++ ) {
    if( $#{$all_ssptn[$ii]} != $#{$all_ssptn[0]} ) {
	     print "SS_LENGTH patterns are not same. \n";
	     exit;
    }
}

###########################################################################
##  make bbskel
###########################################################################
my @mover_sets  = @{$read_input->{mover_sets}};
my @sspairs     = @{$read_input->{sspairs}};
my @bbskel      = ();

my $write_bbskel = WRITE_BBSKEL->new;

my $ptnnum = 0;
my @bbskels_filter;
my @bbskels_mover;

#foreach my $p ( @{$ssptn->{SSL1}} ) {
for( my $kk=0; $kk<=$#{$ssptn->{SSL1}}; $kk++ ) {

    ### make bbskel
    $ptnnum ++;
    my $buildnum = 0;
    my $prev_ssptn = "";
    for ( my $ii=0; $ii<=$#mover_sets; $ii++ ) {

      my ( $mode, $ssl ) = split( "_", $mover_sets[$ii] );
	    my $step = $ii + 1;

      my $p = ${$ssptn->{$ssl}}[$kk];

      my $bbskel_filter = "";
      if ( $mode eq "BUILD" ) {

	       $buildnum ++;
         my $bbb = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".build.bbskel";
         open( BBB, ">$bbb" ) || die ( "cannot open $bbb\n" );
         my $init = 0;

          if( $buildnum == 1 ) {
            $init = 1;
          }
          $write_bbskel->build( *BBB, $p, $instructions->{$ssl}, $sspairs[$ii], $init );
          close( BBB );

          $bbskel_filter = $bbb;
          $bbskel_mover = $bbb;

      } elsif ( $mode eq "REBUILD" ) {

	        my $bbb = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".build.bbskel";
          open( BBB, ">$bbb" ) || die ( "cannot open $bbb\n" );
          $write_bbskel->rebuild( "build", *BBB, $p, $prev_ssptn, $instructions->{$ssl}, $sspairs[$ii], 1, 1 );
          close( BBB );

          $bbskel_mover = $bbb;

          my $bbf = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter1.bbskel";
          open( BBF, ">$bbf" ) || die ( "cannot open $bbf\n" );
          $write_bbskel->rebuild( "filter", *BBF, $p, $prev_ssptn, $instructions->{$ssl}, $sspairs[$ii], 1, 1 );
          # print "$mode $p $instructions->{$ssl}\n";
          close( BBF );
#          print "$ii $mode ";
          my $ssmap = GET_SSMAP->new;
          $ssmap->read( $p, $instructions->{$ssl} );

          #if( $ssmap->{term_rebuild} ) {
          my $bbf2 = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter2.bbskel";
          open( BBF, ">$bbf2" ) || die ( "cannot open $bbf2\n" );
          $write_bbskel->all_dot( *BBF, $p, $sspairs[$ii], $instructions->{$ssl} );
          close( BBF );
          $bbskel_filter = $bbf.",".$bbf2;
          #} else {
          #  $bbskel_filter = $bbf;
          #}

      } elsif ( $mode eq "SHEET-REFINE" ) {

          my $bbb = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".build.bbskel";
          open( BBB, ">$bbb" ) || die ( "cannot open $bbb\n" );
          $write_bbskel->all_dot( *BBB, $p, $sspairs[$ii], $instructions->{$ssl}  );
          close( BBB );

          my $bbf = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter.bbskel";
          open( BBF, ">$bbf" ) || die ( "cannot open $bbf\n" );
          $write_bbskel->sheet_build_filter( *BBF, $p, $instructions->{$ssl}, $sspairs[$ii], 1, 1 );
          close( BBF );

          $bbskel_filter = $bbf;
          $bbskel_mover = $bbb;

      } elsif ( $mode =~  m/FINAL-REFINE/ ) {

          my $bbb = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".build.bbskel";
          open( BBB, ">$bbb" ) || die ( "cannot open $bbb\n" );
          $write_bbskel->all_dot( *BBB, $p, $sspairs[$ii], $instructions->{$ssl} );
          close( BBB );

          my $bbf = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter.bbskel";
          open( BBF, ">$bbf" ) || die ( "cannot open $bbf\n" );
          $write_bbskel->all_dot( *BBF, $p, $sspairs[$ii], $instructions->{$ssl} );
          close( BBF );

          $bbskel_filter = $bbf;
          $bbskel_mover = $bbb;

      }

      # store ssptn information for rebuild
      $prev_ssptn = $p;

      push( @{$bbskels_filter[$ptnnum]}, $bbskel_filter );
      push( @{$bbskels_mover[$ptnnum]},  $bbskel_mover  );


#      print "$p $mode $bbskel_filter, $bbskel_mover were made.\n";

    }

}

###########################################################################
##  make xml
###########################################################################
my @extra_files = @{$read_input->{extra_files}};

my $joblist_elm = "$optn{dir}/joblist_dig";
open( JOBLIST_ELM, ">$joblist_elm" ) || die( "cannot open $joblist_elm\n" );

my $write_xml = WRITE_XML->new;

my $totptn = $#{$ssptn->{SSL1}}+1;
for( my $ii=1; $ii<=$totptn; $ii++ ) {

   my $xml = $outdir."/inputs/"."ptn".$ii.".xml";
   open( *XML, ">$xml" ) || die (" cannot open $xml \n");
   print XML "<dock_design>\n\n";

   # score
   for ( my $jj=0; $jj<=$#mover_sets; $jj++ ) {
    my ( $mode, $ssl ) = split( "_", $mover_sets[$jj] );
    my $init_close = "";
    if ( $jj==0 ) {
      $init_close = "init";
    } elsif ( $jj==$#mover_sets ) {
      $init_close = "close";
    }
    if ( $jj==0 && $jj==$#mover_sets ) {
      $init_close = "init_close";
    }

    my $ssmap = GET_SSMAP->new;
    my $ss = $ssptn->{$ssl}[$ii-1];
    $ssmap->read( $ss, $instructions->{$ssl} );
    $write_xml->score( *XML, $mode, $jj+1, $init_close, $ssmap );
   }

   #task_operations
   $write_xml->task_operation( *XML );

   #filter
   for ( my $jj=0; $jj<=$#mover_sets; $jj++ ) {
     my ( $mode, $ssl ) = split( "_", $mover_sets[$jj] );
     my $init_close = "";
     if ( $jj==0 ) {
       $init_close = "init";
     } elsif ( $jj==$#mover_sets ) {
       $init_close = "close";
     }
     if ( $jj==0 && $jj==$#mover_sets ) {
       $init_close = "init_close";
     }

     my $ssmap = GET_SSMAP->new;
     my $ss = $ssptn->{$ssl}[$ii-1];
     $ssmap->read( $ss, $instructions->{$ssl} );
     $write_xml->filter( *XML, $mode, $jj+1, $init_close, $bbskels_filter[$ii][$jj], $sspairs[$jj], $ssmap );
  }

  #mover
  for ( my $jj=0; $jj<=$#mover_sets; $jj++ ) {
    my ( $mode, $ssl ) = split( "_", $mover_sets[$jj] );
    my $init_close = "";
    if ( $jj==0 ) {
      $init_close = "init";
    } elsif ( $jj==$#mover_sets ) {
      $init_close = "close";
    }
    if ( $jj==0 && $jj==$#mover_sets ) {
      $init_close = "init_close";
    }

    my $ssmap = GET_SSMAP->new;
    my $ss = $ssptn->{$ssl}[$ii-1];
    $ssmap->read( $ss, $instructions->{$ssl} );

    my $exfiles = "";
    if( defined( $extra_files[$jj] ) ) {
      $exfiles = $extra_files[$jj];
    }

    $write_xml->mover( *XML, $mode, $jj+1, $init_close, $bbskels_mover[$ii][$jj], $ssmap, $exfiles );

    # information
    printf INFO "# $ssl mode=${mode} LENGTH=%4s\n", $get_ssptn->get_length( $ss );
    print  INFO "# $ii $ss \n";
    print  INFO "#\n";
  }

  print  INFO "\n";

 # protocols
 $write_xml->protocols( *XML );
 print XML "</dock_design>\n";
 close(XML);

 # make elm jobs
 my $dir = $outdir."/data/".${ii};
 my $arg = $ARGS." -parser:protocol $xml -out:file:silent \$(Process).silent";
 if ( !-e $dir ) {
   system( "mkdir $dir");
 }
 for ( $k=1; $k<=$optn{njobs}; $k++ ) {
   my $arg = $ARGS." -parser:protocol $xml -out:file:silent ${dir}/${k}.silent";
   print JOBLIST_ELM "$EXEC $arg > ${dir}/${k}.log \n";
 }

}
close(JOBLIST_ELM);

system( "cd ${outdir} ; ~/scripts/make_jsub.pl --jobtype=$optn{jobtype} --queue=$optn{queue} --list=joblist_dig --npara=$optn{npara} " );
print( "cd ${outdir} ; ~/scripts/make_jsub.pl --jobtype=$optn{jobtype} --queue=$optn{queue} --list=joblist_dig --npara=$optn{npara} \n" );

$read_input->dump(*INFO);

print "All input files were produced.\n";

open( ANAL, ">$outdir/analyze.sh");
print ANAL "#/bin/bash\n\n";
print ANAL "cd $outdir; nohup $average -in:file:silent $outdir/data/1/*.silent  >& /dev/null & \n";
print ANAL "cd $outdir; nohup $analyze -nooutput -in:file:centroid_input -in:file:silent $outdir/data/1/*.silent >& /dev/null & ; $anal_R_1; $anal_R_2  \n";
close( ANAL );
system( "chmod +x $outdir/analyze.sh");




exit;
