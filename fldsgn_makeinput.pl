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
  #force => {
  #  type => 'bool',
  #  description => 'remove directory and create new directory',
  #  default => 0,
  #},
  pdb => {
    type => 'string',
    default => '/pdb/input.pdb',
  },
  njobs => {
	  type => 'integer',
    default => 10,
	},
  nstruct => {
	  type => 'integer',
    default => 500,
  },

  },
);

my $PWD = `pwd`; chomp $PWD;

# intput pdb setup
my $h = $optn{pdb};
$h =~ s/^\.//;
my $INPUT_PDB = $PWD.$h;

# rosetta
my $EXEC = "/home/nobuyasu/rosetta/mini/bin/rosetta_scripts.linuxgccrelease";
my $ARGS = " -database /home/nobuyasu/rosetta/rosetta_database -s $INPUT_PDB -nstruct $optn{nstruct} -frags::vall_size 200000";

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
my $read_input = READ_INPUTS->new;
$read_input->read( $optn{input} );

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

foreach my $p ( @{$ssptn->{SSL1}} ) {

    chop $p;

    ### make bbskel
    $ptnnum ++;
    my $buildnum = 0;
    for ( my $ii=0; $ii<=$#mover_sets; $ii++ ) {

      my ( $mode, $ssl ) = split( "_", $mover_sets[$ii] );
	    my $step = $ii + 1;

      my $bbskel_filter = "";
      if ( $mode eq "BUILD" ) {

	       $num_build ++;
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

	        $num_build ++;
	        my $bbb = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".build.bbskel";
          open( BBB, ">$bbb" ) || die ( "cannot open $bbb\n" );
          $write_bbskel->rebuild( "build", *BBB, $p, $instructions->{$ssl}, $sspairs[$ii], 1, 1 );
          close( BBB );

          $bbskel_mover = $bbb;

          my $bbf = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter1.bbskel";
          open( BBF, ">$bbf" ) || die ( "cannot open $bbf\n" );
          $write_bbskel->rebuild( "filter", *BBF, $p, $instructions->{$ssl}, $sspairs[$ii], 1, 1 );
          # print "$mode $p $instructions->{$ssl}\n";
          close( BBF );
#          print "$ii $mode ";
          my $ssmap = GET_SSMAP->new;
          $ssmap->read( $p, $instructions->{$ssl} );

          if( $ssmap->{term_rebuild} ) {
            my $bbf2 = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".filter2.bbskel";
            open( BBF, ">$bbf2" ) || die ( "cannot open $bbf2\n" );
            $write_bbskel->all_dot( *BBF, $p, $sspairs[$ii] );
            close( BBF );
            $bbskel_filter = $bbf.",".$bbf2;
          } else {
            $bbskel_filter = $bbf;
          }

      } elsif ( $mode eq "SHEET-REFINE" ) {

	        $num_build ++;
          my $bbf = $outdir."/inputs/"."ptn".$ptnnum."-step".$step.".bbskel";
          open( BBF, ">$bbf" ) || die ( "cannot open $bbf\n" );
          $write_bbskel->sheet_build_filter( *BBF, $p, $instructions->{$ssl}, 0, 0 );
          close( BBF );

          $bbskel_filter = $bbf;
          $bbskel_mover = $bbf;
	    }

      push( @{$bbskels_filter[$ptnnum]}, $bbskel_filter );
      push( @{$bbskels_mover[$ptnnum]},  $bbskel_mover  );

    }

}

###########################################################################
##  make xml
###########################################################################
my $joblist_elm = "$optn{dir}/joblist_dig";
open( JOBLIST_ELM, ">$joblist_elm" ) || die( "cannot open $joblist_elm\n" );

my $write_xml = WRITE_XML->new;

my $totptn = $#{$ssptn->{SSL1}}+1;
for( my $ii=1; $ii<=$totptn; $ii++ ) {

   my $xml = $outdir."/inputs/"."ptn".$ii.".xml";
   open( *XML, ">$xml" ) || die (" cannot open $xml \n");
   print XML "<dock_design>\n\n";

   $ss = $ssptn->{SSL1}[$ii-1];

   # score
   for ( my $jj=0; $jj<=$#mover_sets; $jj++ ) {
    my ( $mode, $ssl ) = split( "_", $mover_sets[$jj] );
    my $init_close = "";
    if ( $jj==0 ) {
      $init_close = "init";
    } elsif ( $jj==$#mover_sets ) {
      $init_close = "close";
    }
    my $ssmap = GET_SSMAP->new;
    $ssmap->read( $ss, $instructions->{$ssl} );
    $write_xml->score( *XML, $mode, $jj, $init_close, $ssmap );
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
     my $ssmap = GET_SSMAP->new;
     $ssmap->read( $ss, $instructions->{$ssl} );
     $write_xml->filter( *XML, $mode, $jj, $init_close, $bbskels_filter[$ii][$jj], $ssmap );
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
    my $ssmap = GET_SSMAP->new;
    $ssmap->read( $ss, $instructions->{$ssl} );
    $write_xml->mover( *XML, $mode, $jj, $init_close, $bbskels_mover[$ii][$jj], $ssmap, "" );
 }

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

 # information
 print INFO "$ii $ss \n";


}
close(JOBLIST_ELM);

$read_input->dump(*INFO);

print "All input files were produced.\n";

exit;
