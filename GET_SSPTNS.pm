#!/usr/bin/perl -w

package GET_SSPTNS;

sub new {
    my $class = shift;
    my $self = bless {
      inst     => undef,
      ssptn    => undef,
    },$class;
    return $self;
}

##############################################################################################
sub read {

  my $this = shift;
  my ( $ss_length ) = @_;

  my $inst = "";
  my @ptn = ("");
  my $base_num = 1;
  foreach my $f ( @$ss_length ) {

    my ( $status, $aa ) = split( '-', $f );

    $inst = $inst.$status."-";

    my @dat = split( '\.', $aa );

    if ( $dat[0] eq "L" ) {
	     if( $#dat != 2 ) {
         die( "Input error, $f. \n" );
       }
    } elsif ( $dat[0] =~ m/[E,U,S]/ && length($dat[0]) >= 2 ) {

      if( length($dat[0]) != $dat[1] ) {
        die( "Strand input and its length are not consistent: $dat[0], $dat[1]" );
      }

    } elsif ( $#dat == 0 && $dat[0] eq "Q" ) {

      for( $i=0; $i<=$#ptn; $i++ )  {
         $ptn[$i] = $ptn[$i]."Q-";
      }
      next;

    } else {
       if( $#dat != 1 ) {
         die( "Input error, $f .\n" );
       }
    }

    my @length = split( ",", $dat[1] );

    my @abego = ();
    if( $#dat == 2 ) {
      @abego  = split( ",", $dat[2] );
    }

    my $trn_ptn  = 0;
    if( $dat[0] eq "L" ) {

      foreach my $l (@length) {
        foreach my $a (@abego) {
          if( $l == length($a) ) {
             $trn_ptn ++;
          }
        }
      }

	    if( $trn_ptn == 0 ) {
        die("Input error @dat \n")
	    }

    } else {
	    $trn_ptn = 1;
    }

    my @baseptn = ();
    for( my $i=1; $i<=$base_num; $i++ ) {
	    push( @baseptn, $ptn[$i-1] );
    }

    my $abego_ptn = 0;
    my $num = 0;
    for ( my $i=1; $i<=$base_num; $i++ ) {

	    foreach $l ( @length ) {

        if( $#dat != 2 ) {
		      $ptn[$num]  = $baseptn[$i-1].$dat[0].".".$l."-";
		      $num ++;
		    } else {
		      foreach my $a ( @abego ) {
			      if( length( $a ) == $l ) {
			        $ptn[$num] = $baseptn[$i-1].$dat[0].".".$l.".".$a."-";
			        $num ++;
			      }
		      }
        }

      }
    }

    if ( $#length > 0 || $trn_ptn > 0 ) {
	    if ( $dat[0] eq "L" ) {
        $base_num = $base_num * $trn_ptn;
	    } else {
        $base_num = $base_num * ( $#length + 1 );
	    }
    }
  }

  chop $inst;

  $this->{inst} = $inst;
  $this->{ssptn} = \$ptn;

  return \@ptn;

}

##############################################################################################
sub get_length {

  my $this = shift;
  my ( $ssptn ) = @_;

  my @ssptn = split( '-', $ssptn );
  my $len = 0;
  foreach my $ss ( @ssptn ){

    my @dat = split( '\.', $ss );

    #my $abego;
    #if ( $dat[0] eq "L" ) {
    #  $abego = $dat[2];
  #} elsif ( $dat[0] eq "H" ) {
	#    $abego = "A";
  #  } elsif ( $dat[0] eq "E" ) {
	#    $abego = "B";
  #  } elsif ( $dat[0] eq "Q" ) {
	#    next;
  #  } else {
	#    die ( "Error, $dat[0]\n" );
  #  }

	   $len += $dat[1];
   }
    return $len;
}

1;
