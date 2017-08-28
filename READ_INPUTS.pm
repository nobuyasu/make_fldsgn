#!/usr/bin/perl -w

package READ_INPUTS;

sub new {
    my $class = shift;
    my $self = bless {
      filename => undef,
      sspairs  => undef,
      mover_sets  => undef,
      ss_patterns   => undef,
    },$class;
    return $self;
}

sub dump {

  my $this = shift;
  my ( $fh ) = @_;

  open( INP, $this->{filename} ) || die( "cannot open $this->{filename}\n" );
  while ( my $line = <INP> ) {
    print $fh "$line";
  }
  close(INP);

}

sub read {

     my $this = shift;
     my ( $input ) = @_;

     my @topology = ();
     my $ss_len = ""; my $type = "";
     my $f_len  = ""; my $f_top = 0;
     my @sslen_name = ();

     open( INP, $input ) || die( "cannot open $input" );

     my $fh = *INP;

     while ( my $line = <$fh>) {

       chomp $line;
       $line =~ s/[ \t\n]+//g;

       next if( $line =~ m/^#/ );

       if( $line =~ m/SSLENGTH/ ) {

	        ( my $h, $ss ) = split( "=", $line );
          $h =~ s/ENGTH_//;
          push( @sslen_name, $h );
          $f_len = $h;

          $ss_len{$h} = $ss;
          if ( $ss_len{$h} =~ m/\)/ ) {
            $ss_len{$h} =~ s/[\(\)]//g;
          } else {
            next;
          }
      }

      if( $f_len ne "" ) {
        $ss_len{$f_len} = $ss_len{$f_len}.$line;
        if ( $ss_len{$f_len} =~ m/\)/ ) {
          $ss_len{$f_len} =~ s/[\(\)]//g;
          $f_len = "";
        }
      }

      if( $line =~ m/SSPAIR/ || $line =~ m/HHPAIR/ || $line =~ m/HSSTRIPLET/  || $line =~ m/MOVER_SETS/ || $line =~ m/EXTRA_FILES/ ) {
        ( $type, my $string ) = split( "=", $line );
        $type = lc($type);
        $top->{$type} = $string;
        #print "$type \n";
        $f_top = 1;

        if ( $top->{$type} =~ m/\)/ ) {
          $top->{$type} =~ s/[\(\)]//g;
          $top->{$type} =~ s/^\"//; $top->{$type} =~ s/\"$//;
          my @top = split( '\"\,\"', $top->{$type} );
          my $n = 0;
          foreach my $t ( @top ) {
            $topology{$type}[$n] = $t;
            $n ++;
          }
          $f_top = 0;
        } else {
          next;
	      }
	    }

	    if( $f_top == 1 ) {
        $top->{$type} = $top->{$type}.$line;
        if ( $top->{$type} =~ m/\)/ ) {
          $top->{$type} =~ s/[\(\)]//g;
          $top->{$type} =~ s/^\"//; $top->{$type} =~ s/\"$//;
          my @top = split( '\"\,\"', $top->{$type} );
          my $n = 0;
          foreach my $t ( @top ) {
            $topology{$type}[$n] = $t;
            $n ++;
          }
          $f_top = 0;
        }
      }
    }
    close( INP );

    $this->{filename} = $input;

    if( $#{$topology{sspair}} != $#{$topology{mover_sets}} ) {
      print " $#{$topology{sspair}}  \n";
      print " $#{$topology{mover_sets}} \n";
      print "Num of SSPAIR and MOVERSETS are not same. \n";
      exit;
    }

    foreach my $a ( @{$topology{sspair}} ) {
      my @sspair = split( '\;', $a );
      foreach $s ( @sspair ) {
        my @k = split( '\.', $s );
        if( $#k != 2 ) {
          die("Input error in sspair, $s of $a .");
        }
      }
    }

    my %ss_pattern;
    foreach my $n ( @sslen_name ) {
      $ss_len{$n} =~ s/^\"//; $ss_len{$n} =~ s/\"$//;
      my @ssptn = split( '\"\,\"', $ss_len{$n} );
      $ss_pattern{$n} = \@ssptn;
    }

    $this->{ss_patterns} = \%ss_pattern;
    $this->{sspairs} = \@{$topology{sspair}};
    $this->{mover_sets} = \@{$topology{mover_sets}};
    $this->{extra_files} = \@{$topology{extra_files}};

}


1;
