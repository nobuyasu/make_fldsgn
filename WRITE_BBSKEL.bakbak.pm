#!/usr/bin/perl -w

package WRITE_BBSKEL;

sub new {
    my $class = shift;
    my $self = bless {
    },$class;
    return $self;
}

##############################################################################################
sub obtain_rebuild_regions {

    my $this = shift;
    my ( $ssptn, $inst ) = @_;

    my @ssptn = split( '-', $ssptn );
    my @inst  = split( '-', $inst  );

    my $read = 0;
    my $tlen = 0;
    my @r_regions = ();
    my $begin;
    my $end;

    for ( my $ii=0; $ii<=$#ssptn; $ii++ ) {

      my $ss   = $ssptn[$ii];
      my $inst = $inst[$ii];

      if ( $inst eq "N" ) {
        next;
      }

      my @dat = split( '\.', $ss );
      my $length = $dat[1];

      if ( $read == 1 && $inst ne "R" ) {
        $end = $tlen;
        my $r_region = {
            begin => $begin,
            end   => $end,
        };
        push( @r_regions, $r_region );
	      $read = 0 ;
	    }

      if( $inst eq "R" && $read == 0 ) {
	       $begin = $tlen + 1;
         $read = 1;
      }

      $tlen += $length;

     }

     if( $read == 1 ) {

       $end = $tlen;
       my $r_region = {
           begin => $begin,
           end   => $end,
       };
       push( @r_regions, $r_region );
       #print "rebuild_region: begin=$r_region->{begin} end=$r_region->{end} \n";
     }
     #print "@r_regions \n";
     return \@r_regions;
}

#################################################################################################
sub all_dot {

  my $this = shift;
  my ( $fh, $ssptn, $sspair, $inst ) = @_;

  my @ssptn = split( '-', $ssptn );
  my @inst  = split( '-', $inst  );

  $ssptn =~ s/\.//g;
  print $fh "# $ssptn\n";

  if( $sspair ne "" ) {
     print $fh "SSPAIR $sspair\n";
  }

  my $line = 0;

  for ( my $ii=0; $ii<=$#ssptn; $ii++ ) {

    my $ss   = $ssptn[$ii];
    my @dat = split( '\.', $ss );

    next if( $inst[$ii] eq "N" );

    my $abego = $dat[2];
    if ( $dat[0] eq "L" ) {
	     $abego = $dat[2];
    } elsif ( $dat[0] eq "H" ) {
	     $abego = "A";
    } elsif ( $dat[0] eq "E" ) {
#	     $abego = "C";
	     $abego = "B";
    } elsif ( $dat[0] =~ m/[E,S,U]/ && length( $dat[0] ) >=2 ) {
	     $abego = "C";
    } elsif ( $dat[0] eq "Q" ) {
	     next;
    } else {
	     die ( "Error, $dat[0]\n" );
    }

    my $ss_string;
    if( length( $dat[0] ) >=2 ) {
	     $ss_string = $dat[0];
    } else {
	     $ss_string = $dat[0] x $dat[1];
    }

    for ( my $i=1; $i<=$dat[1]; $i++ ) {

      my $ss = substr( $ss_string, $i-1, 1 );
      $line ++;
      my $a;
      if ( $ss eq "L" ) {
	       $a = substr( $abego, $i-1, 1 );
      } else {
	       $a = $abego;
      }
      print $fh "$line V $ss$a .\n";
    }

  }

}

##############################################################################################
sub sheet_build_filter {

  my $this = shift;
  my ( $fh, $ssptn, $inst, $sspair, $Nedge_loose, $Cedge_loose ) = @_;

  my @ssptn = split( '-', $ssptn );
  my @inst  = split( '-', $inst  );

  $ssptn =~ s/\.//g;
  print $fh "# $ssptn\n";

  if( $sspair ne "" ) {
     print $fh "SSPAIR $sspair\n";
  }

  my $line = 0;
  my $d_line = 0;
  for ( my $ii=0; $ii<=$#ssptn; $ii++ ) {

    my $ss   = $ssptn[$ii];
    my $inst = $inst[$ii];

	  if ( $inst eq "N" ) {
	    next;
    }

    my @dat = split( '\.', $ss );

    my $abego = $dat[2];
    if ( $dat[0] eq "L" ) {
      $abego = $dat[2];
    } elsif ( $dat[0] eq "H" ) {
	    $abego = "A";
    } elsif ( $dat[0] eq "E" ) {
#	    $abego = "C";
	    $abego = "B";
    } elsif ( $dat[0] =~ m/[E,S,U]/ && length($dat[0]) >=2 ) {
	     $abego = "C";
    } elsif ( $dat[0] eq "Q" ) {
	    next;
    } else {
	    die ( "Error, $dat[0]\n" );
    }

    my $ss_string;
    if( length( $dat[0] ) >=2 ) {
	    $ss_string = $dat[0];
    } else {
      $ss_string = $dat[0] x $dat[1];
    }

    for ( my $i=1; $i<=$dat[1]; $i++ ) {

      my $ss = substr( $ss_string, $i-1, 1 );

	    $line ++;
	    my $a;
	    if ( $ss eq "L" ) {
        $a = substr( $abego, $i-1, 1 );
	    } else {
        $a = $abego;
	    }

	    my $sso = $ss;
	    if( $ss eq "L" or $ss eq "H" ) {
        $sso = "D";
	    } elsif ( $ss eq "E" and $i==$dat[1] and $Cedge_loose ) {
        $sso = "D";
	    } elsif ( $ss eq "E" and $i==1 and $Nedge_loose ) {
        $sso = "D";
	    }

	    print $fh "$line V $sso$a .\n";

	   }
   }
}

#################################################################################################

sub rebuild {

  my $this = shift;
  my ( $mode, $fh, $ssptn, $prev_ssptn, $inst, $sspair, $ex_cterm, $ex_nterm ) = @_;

  my $rebuild_regions = $this->obtain_rebuild_regions( $ssptn, $inst );

  my $rebuild_prevmap = $rebuild_regions;
  if( $prev_ssptn ne "" ) {
    $rebuild_prevmap = $this->obtain_rebuild_regions( $prev_ssptn, $inst );
  }

  my @ssptn = split( '-', $ssptn );
  my @inst  = split( '-', $inst  );

  $ssptn =~ s/\.//g;
  print $fh "# $ssptn\n";

  if( $sspair ne "" ) {
	   print $fh "SSPAIR $sspair\n";
  }

  my $resn = 0;
  my $line = 0;
  for ( my $ii=0; $ii<=$#ssptn; $ii++ ) {

    my $ss   = $ssptn[$ii];
    my $inst = $inst[$ii];

    if ( $inst eq "N" ) {
      next;
    }

    my @dat = split( '\.', $ss );

    my $abego = $dat[2];
    if ( $dat[0] eq "L" ) {
	    $abego = $dat[2];
    } elsif ( $dat[0] eq "H" ) {
	    $abego = "A";
    } elsif ( $dat[0] eq "E" ) {
#	    $abego = "C";
	    $abego = "B";
    } elsif ( $dat[0] =~ m/[E,S,U]/ && length($dat[0]) >=2 ) {
	    $abego = "C";
    } elsif ( $dat[0] eq "Q" ) {
      next;
    } else {
	    die ( "Error, $dat[0]\n" );
    }

    my $ss_string;
    if( length( $dat[0] ) >=2 ) {
	    $ss_string = $dat[0];
    } else {
      $ss_string = $dat[0] x $dat[1];
    }

    my $len  = $dat[1];
    my $flag = 0;
    my $rebuild_region_num = "";

    for ( my $i=1; $i<=$len; $i++ ) {

      my $ss = substr( $ss_string, $i-1, 1 );

	    $line ++;
      $resn ++;
	    my $a;
	    if ( $ss eq "L" ) {
        $a = substr( $abego, $i-1, 1 );
	    } else {
        $a = $abego;
	    }
      my $b = ".";
      if ( $flag == 0 ) {
        for ( my $ii=0; $ii<=$#{$rebuild_regions}; $ii++ ) {
          my $region = ${$rebuild_regions}[ $ii ];
          if ( $line >= ( $region->{begin} - $ex_nterm ) && $line <= ( $region->{end} + $ex_cterm )  ) {
              $flag = 1;
              $rebuild_region_num = $ii;
              last;
          }
        }
      } else {

          my $region = ${$rebuild_regions}[ $rebuild_region_num ];
          unless ( $line >= ( $region->{begin} - $ex_nterm ) && $line <= ( $region->{end} + $ex_cterm )  ) {
		          $flag = 0;
              my $prvmap = ${$rebuild_prevmap}[ $rebuild_region_num ];
              $resn = $prvmap->{end} + 1 + $ex_cterm;
          }

      }

#      print "line = $line $flag \n";

      if( $mode eq "build" ) {
        if( $flag ) {
          $b = "R";
          $sso = $ss;
        } else {
          $b = ".";
          $sso = $ss;
        }
      } elsif ( $mode eq "filter" ) {
        if( $flag ) {
          $b = "R";
          $sso = $ss;
        } else {
          $a = "X";
          $b = ".";
          $sso = "D";
        }
      } else {
        print "mode error, $mode \n";
        exit;
      }

      if ( $flag & $mode eq "build" ) {
         print $fh "0 V $sso$a $b\n";
      } else {
	       print $fh "$resn V $sso$a $b\n";
      }

    }
  }

}

#################################################################################################
sub build {

  my $this = shift;
  my ( $fh, $ssptn, $inst, $sspair, $init ) = @_;

  print "make bbskel for $ssptn, $inst \n";

  my @ssptn = split( '-', $ssptn );
  my @inst  = split( '-', $inst  );

  $ssptn =~ s/\.//g;
  print $fh "# $ssptn\n";

  if( $sspair ne "" ) {
	   print $fh "SSPAIR $sspair\n";
  }

  my $line = 0;
  my $d_line = 0;

  for ( my $ii=0; $ii<=$#ssptn; $ii++ ) {

    my $ss   = $ssptn[$ii];
    my $inst = $inst[$ii];

    if ( $inst eq "N" ) {
	     next;
	  }

    my @dat = split( '\.', $ss );

    my $abego = $dat[2];
    if ( $dat[0] eq "L" ) {
      $abego = $dat[2];
    } elsif ( $dat[0] eq "H" ) {
	    $abego = "A";
    } elsif ( $dat[0] eq "E" ) {
#	    $abego = "C";
	    $abego = "B";
    } elsif ( $dat[0] =~ m/[E,S,U]/ && length($dat[0]) >=2 ) {
	    $abego = "C";
    } elsif ( $dat[0] eq "Q" ) {
	    next;
    } else {
	    die ( "Error, $dat[0]\n" );
    }

    my $ss_string;
    if( length( $dat[0] ) >=2 ) {
	    $ss_string = $dat[0];
    } else {
      $ss_string = $dat[0] x $dat[1];
    }

    for ( my $i=1; $i<=$dat[1]; $i++ ) {

      my $ss = substr( $ss_string, $i-1, 1 );

	    $line ++;
	    my $a;
      if ( $ss eq "L" ) {
	       $a = substr( $abego, $i-1, 1 );
      } else {
	       $a = $abego;
	    }

	    if ( $init ) {
		    if( $line <=2 ) {
	        print $fh "$line V $ss$a R\n";
		    } else {
          print $fh "0 V $ss$a R\n";
		    }
		    next;
	    }

	    if ( $inst eq "D" ) {
		    $d_line ++;
		    print $fh "$d_line V $ss$a .\n";
	    } elsif ( $inst eq "R" ) {
		    print $fh "0 V $ss$a R\n";
	    }
    }
  }

}



1;
