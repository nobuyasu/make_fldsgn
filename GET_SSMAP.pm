#!/usr/bin/perl -w

package GET_SSMAP;

sub new {
    my $class = shift;
    my $self = bless {
      nssid  => undef,
      nhelix => undef,
      nstrand => undef,
      nloop => undef,
      rebuild => undef,
      helix_ssid => undef,
      strand_ssid => undef,
      loop_ssid => undef,
      ssid_hleid => undef,
      term_rebuild => undef,
      rebuild_helices => undef,
      rebuild_loops => undef,
    },$class;
    return $self;
}

##############################################################################################
sub read {

  my $this = shift;
  my ( $ssptn, $inst ) = @_;

  my $loop   = 0;
  my $helix  = 0;
  my $strand = 0;

  my @ssptn = split( '-', $ssptn );
  my @inst  = split( '-', $inst );

  my %ssid_hleid;
  my %helix_ssid;
  my %loop_ssid;
  my %strand_ssid;
  my @rebuild;
  my @rebuild_helices;

  for ( my $ii=1; $ii<=$#ssptn+1; $ii++ ) {

    my $ss   = $ssptn[$ii-1];
    my @dat = split( '\.', $ss );
    my $s   = $dat[0];

    if( $s =~m/[E,S,U]/ && length($s)>=2 ) {
      $s = "E";
    }

    if( $s eq "L" ) {
      $loop ++;
      $loop_ssid[$loop] = $ii;
      $ssid_hleid[$ii] = $loop;
    } elsif( $s eq "H" ) {
      $helix ++;
      $helix_ssid[$helix] = $ii;
      $ssid_hleid[$ii] = $helix;
    } elsif( $s eq "E" ) {
      $strand ++;
      $strand_ssid[$strand] = $ii;
      $ssid_hleid[$ii] = $strand;
    }

    if ( $inst[$ii-1] eq "R" ) {
      $rebuild[$ii] = 1;
      if ( $s eq "H" ) {
        push( @rebuild_helices, $helix );
      }
    } elsif ( $inst[$ii-1] eq "N" ) {
      next;
    } else {
      $rebuild[$ii] = 0;
    }

#    my $inst = $inst[$ii];
    #print "$dat[0] $dat[1] $loop $helix $strand\n";

  }

  $this->{nssid} = $#ssptn + 1;

  $this->{rebuild} = \@rebuild;

  $this->{nhelix} = $helix;
  $this->{nloop}  = $loop;
  $this->{nstrand} = $strand;

  $this->{ssid_hleid} = \%ssid_hleid;
  $this->{hleid_ssid} = \%hleid_ssid;

  $this->{term_rebuild} = 0;
  my $rebuild_loops = "";
  my $rebuild_helices = "";
  foreach $h ( @rebuild_helices ) {

    if(  $h == 1 && $helix_ssid[ 1 ] <= 2 ) {

      print "$helix_ssid[ 1 ] \n";

      my $l = $ssid_hleid[ $helix_ssid[ 1 ] + 1 ];
      $rebuild_loops = $rebuild_loops.$l.",";
      $this->{term_rebuild} = 1;

    } elsif ( $h == $this->{nhelix} && $helix_ssid[ $helix ] >= $this->{nssid} - 1 ) {

      my $l = $ssid_hleid[ $helix_ssid[ $h ] - 1 ];
      $rebuild_loops = $rebuild_loops.$l.",";
      $this->{term_rebuild} = 1;

    } else {

      my $l1 = $ssid_hleid[ $helix_ssid[ $h ] - 1 ];
      my $l2 = $ssid_hleid[ $helix_ssid[ $h ] + 1 ];
      $rebuild_loops = $rebuild_loops.$l1.",".$l2.",";

    }
    $rebuild_helices = $rebuild_helices.$h.",";

  }
  chop $rebuild_loops;
  chop $rebuild_helices;

  $this->{rebuild_loops} = $rebuild_loops;
  $this->{rebuild_helices} = $rebuild_helices;

}

1;
