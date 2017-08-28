 #!/usr/bin/perl -w

package WRITE_XML;

use GET_SSMAP;

sub new {

    my $class = shift;
    my $self = bless {
      movers => undef,
    },$class;

    $this->{movers} = \@movers;

    return $self;
}

##############################################################################################
sub header_footer {

  my $this = shift;
  my ( $fh, $init_close ) = @_;

  if ( $init_close eq "init" ) {
    print $fh "<dock_design>\n\n";
  }

  if( $init_close eq "close" ) {
    print $fh "</dock_design>\n\n";
  }

}

##############################################################################################
sub score {

  my $this = shift;
  my ( $fh, $mode, $num, $init_close, $ssmap ) = @_;

  if( $init_close eq "init") {
    print $fh "<SCOREFXNS>\n\n";
  }

  if ( $mode eq "BUILD" ) {

    if( $ssmap->{term_rebuild} ) {
      print $fh "<SFXN${num} weights=fldsgn_cen >\n";
      print $fh "  < Reweight scoretype=hbond_lr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=hbond_sr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=atom_pair_constraint weight=1.0 />\n";
      print $fh "</SFXN${num}>\n\n";
    } else {
      print $fh "<SFXN${num} weights=fldsgn_cen >\n";
      print $fh "  < Reweight scoretype=hbond_lr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=hbond_sr_bb weight=1.0 />\n";
      print $fh "</SFXN${num}>\n\n";
    }

  } elsif ( $mode eq "REBUILD" ) {

    if( $ssmap->{term_rebuild} ) {
      print $fh "<SFXN${num} weights=fldsgn_cen >\n";
      print $fh "  < Reweight scoretype=hbond_lr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=hbond_sr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=atom_pair_constraint weight=1.0 />\n";
      print $fh "</SFXN${num}>\n\n";
    } else {
      print $fh "<SFXN${num} weights=fldsgn_cen >\n";
      print $fh "  < Reweight scoretype=hbond_lr_bb weight=1.0 />\n";
      print $fh "  < Reweight scoretype=hbond_sr_bb weight=1.0 />\n";
#      print $fh "  < Reweight scoretype=rama weight=0.1 />\n";
      print $fh "  < Reweight scoretype=omega weight=1.0 />\n";
      print $fh "</SFXN${num}>\n\n";
    }

  } elsif ( $mode eq "SHEET-REFINE" || $mode =~ m/FINAL-REFINE/ ) {

    print $fh "<SFXN${num} weights=myweight >\n";
    print $fh "  < Reweight scoretype=atom_pair_constraint weight=1.0 />\n";
    print $fh "  < Reweight scoretype=hbond_sr_bb weight=5.0 />\n";
    print $fh "  < Reweight scoretype=hbond_lr_bb weight=5.0 />\n";
    print $fh "</SFXN${num}>\n\n";

  } elsif ( $mode eq "DESIGN" ) {

    print $fh "<SFXN${num} weights=myweight >\n";
    print $fh "  < Reweight scoretype=atom_pair_constraint weight=1.0 />\n";
    print $fh "</SFXN${num}>\n\n";

  } else {


  }

  if( $init_close eq "close" ) {
    print $fh "</SCOREFXNS>\n\n";
  }

}

##############################################################################################
sub task_operation {

  my $this = shift;
  my ( $fh ) = @_;

  print $fh "<TASKOPERATIONS>\n";
  print $fh "  <LimitAromaChi2 name=limitchi2/>\n";
  print $fh "  <LayerDesign name=layer_all layer=core_boundary_surface  core_H=15 core_E=15 core_L=25 surface_H=60 surface_E=60 surface_L=40 pore_radius=2.0 verbose=true/>\n";
  print $fh "  <ReducedAADesign name=raa />\n";
  print $fh "</TASKOPERATIONS>\n\n";

}
##############################################################################################
sub filter {

    my $this = shift;
    my ( $fh, $mode, $num, $init_close, $bbskel, $sspair, $ssmap ) = @_;

    if( $init_close eq "init" ) {
      print $fh "<FILTERS>\n\n";
    }

    if ( $mode eq "BUILD" ) {

      print $fh "##${num}:BUILD\n";
      print $fh "  <HelixKink     name=hk${num} blueprint=\"$bbskel\" />\n";
      print $fh "  <SheetTopology name=st${num} blueprint=\"$bbskel\" topology=\"$sspair\" />\n";
      print $fh "  <CompoundStatement name=ft${num} >\n";
      print $fh "    <AND filter_name=hk${num}/>\n";
      print $fh "    <AND filter_name=st${num}/>\n";
      print $fh "  </CompoundStatement>\n\n";

    } elsif ( $mode eq "REBUILD" ) {

      print $fh "##${num}:REBUILD\n";
      my $target_helices = $ssmap->{rebuild_helices};
      my ( $bbskel1, $bbskel2 ) = split( ",", $bbskel );

      my $calc_helices   = $ssmap->{rebuild_helices};
      my $calc_loops     = $ssmap->{rebuild_loops};
      my $calc_strands = "";
      for( my $ii=1; $ii<=$ssmap->{nstrand}; $ii++ ) {
        $calc_strands = $calc_strands.$ii.",";
      }
      chop $calc_strands;

      if( $ssmap->{term_rebuild} ) {

        print $fh "  <HelixKink     name=hk${num} blueprint=\"$bbskel2\" helices=${target_helices}/>\n";
        print $fh "  <SecondaryStructure name=ss${num} blueprint=\"$bbskel1\" use_abego=1 check_strandpairing=1 />\n";
        print $fh "  <NumResSASA name=nrs${num} blueprint=\"$bbskel2\" threshold=1 calc_helices=${target_helices} calc_strands=${calc_strands} calc_loops=${calc_loops} target_helices=${target_helices} res_window_helix=5 upper=40 />\n";
        print $fh "  <CompoundStatement name=ft${num} >\n";
        print $fh "    <AND filter_name=hk${num}/>\n";
        print $fh "    <AND filter_name=ss${num}/>\n";
        print $fh "    <AND filter_name=nrs${num}/>\n";
        print $fh "  </CompoundStatement>\n\n";

      } else {

        print $fh "  <HelixKink     name=hk${num} blueprint=\"$bbskel2\" helices=${target_helices} />\n";
        print $fh "  <SecondaryStructure name=ss${num} blueprint=\"$bbskel1\"  use_abego=1 check_strandpairing=1/>\n";
        print $fh "  <NumResSASA name=nrs${num} blueprint=\"$bbskel2\" threshold=1 calc_helices=${target_helices} calc_strands=${calc_strands} calc_loops=${calc_loops} target_helices=${target_helices} res_window_helix=5 upper=40 />\n";
        print $fh "  <CompoundStatement name=ft${num} >\n";
        print $fh "    <AND filter_name=hk${num}/>\n";
        print $fh "    <AND filter_name=ss${num}/>\n";
        print $fh "    <AND filter_name=nrs${num}/>\n";
        print $fh "  </CompoundStatement>\n\n";

      }

    } elsif ( $mode eq "SHEET-REFINE" || $mode =~ m/FINAL-REFINE/ ) {

      print $fh "##${num}:${mode}\n";
      print $fh "  <SecondaryStructure name=ft${num} blueprint=\"$bbskel\" check_strandpairing=1 />\n\n";

    } elsif ( $mode eq "DESIGN" ) {

      print "##${num}:DESIGN\n";
      print $fh "  <PackStat name=pstat threshold=0.60 />\n\n";
      print $fh "  <Holes    name=holes threshold=2.0 cmd=\"~/rosetta/rosetta_database/DAlphaBall.icc\" />\n\n";
      print $fh "  <SecondaryStructure name=ft${num} blueprint=\"$bbskel\" use_abego=1 check_strandpairing=1/>\n";

    } else {


    }

    if( $init_close eq "close" ) {
      print $fh "</FILTERS>\n\n";
    }

}

##############################################################################################
sub mover {

  my $this = shift;
  my ( $fh, $mode, $num, $init_close, $bbskel, $ssmap, $extra_file ) = @_;

  if( $init_close eq "init" ) {
    print $fh "<MOVERS>\n";
    print $fh "  <Dssp name=dssp/>\n\n";
  }

  if ( $mode eq "BUILD" || $mode eq "REBUILD" ) {

    print $fh "##${num}:${mode}\n";

    my $iterations = 20;
    if( $mode eq "REBUILD" ) {
      $iterations = 50;
    }

    if( $ssmap->{term_rebuild} ) {
      print $fh "  <SetSecStructEnergies name=sse${num} blueprint=\"$bbskel\" scorefxn=SFXN${num} />\n";
      print $fh "  <BluePrintBDR   name=bdr${num} scorefxn=SFXN${num} blueprint=\"$bbskel\" use_abego_bias=1 constraints_NtoC=10.0 constraints_NtoC_dist=15 />\n";
      print $fh "  <LoopOver name=lover${num} mover_name=bdr${num} filter_name=ft${num} iterations=$iterations drift=0 ms_whenfail=FAIL_DO_NOT_RETRY/>\n\n";
    } else {
      print $fh "  <SetSecStructEnergies name=sse${num} blueprint=\"$bbskel\" scorefxn=SFXN${num} />\n";
      print $fh "  <BluePrintBDR   name=bdr${num} scorefxn=SFXN${num} blueprint=\"$bbskel\" use_abego_bias=1/>\n";
      print $fh "  <LoopOver name=lover${num} mover_name=bdr${num} filter_name=ft${num} iterations=$iterations drift=0 ms_whenfail=FAIL_DO_NOT_RETRY/>\n\n";
    }

    push ( @{$this->{movers}}, "sse${num}" );
    push ( @{$this->{movers}}, "lover${num}" );

  } elsif( $mode eq "SHEET-REFINE" || $mode eq "FINAL-REFINE" || $mode eq "FINAL-REFINE-THREADSEQ" ) {

    if( $mode eq "FINAL-REFINE-THREADSEQ" ) {

      if( ${extra_file} eq "" ) {
        die( "no input pdb for threading sequence.");
      }

      print $fh "##${num}:${mode}\n";
      print $fh "  <SimpleThreading name=threadseq query_pdb=\"${extra_file}\" />\n";
      print $fh "  <FlxbbDesign ncycles=1 name=design${num} constraints_sheet=10.0 blueprint=\"$bbskel\" sfxn_relax=SFXN${num} no_design=1 filter_trial=1/>\n";
      print $fh "  <ParsedProtocol name=sheet_refine_move${num}>\n";
      print $fh "    <Add mover_name=design${num} />\n";
      print $fh "    <Add mover_name=dssp />\n";
      print $fh "  </ParsedProtocol>\n";
      print $fh "  <LoopOver name=sheet_refine${num} mover_name=sheet_refine_move${num} filter_name=ft${num} iterations=3 drift=1 ms_whenfail=FAIL_DO_NOT_RETRY/>\n\n";

      push ( @{$this->{movers}}, "threadseq" );

    } else {

      print $fh "##${num}:${mode}\n";
      print $fh "  <FlxbbDesign ncycles=1 name=design${num} constraints_sheet=10.0 blueprint=\"$bbskel\" sfxn_design=SFXN${num} sfxn_relax=SFXN${num} task_operations=raa filter_trial=1/>\n";
      print $fh "  <ParsedProtocol name=sheet_refine_move${num}>\n";
      print $fh "    <Add mover_name=design${num} />\n";
      print $fh "    <Add mover_name=dssp />\n";
      print $fh "  </ParsedProtocol>\n";
      print $fh "  <LoopOver name=sheet_refine${num} mover_name=sheet_refine_move${num} filter_name=ft${num} iterations=3 drift=1 ms_whenfail=FAIL_DO_NOT_RETRY/>\n\n";

    }

    push ( @{$this->{movers}}, "sheet_refine${num}" );

  } elsif ( $mode eq "DESIGN" ) {

    print "##${num}:DESIGN\n";
    if( $extra_file eq "" ) {
      print $fh "  <FlxbbDesign ncycles=1 name=design${num} constraints_sheet=10.0 constraints_NtoC=10.0 constraints_NtoC_dist=15 blueprint=\"$bbskel\" sfxn_design=SFXN${num} sfxn_relax=SFXN${num} task_operations=limitchi2,layer_all filter_trial=1/>\n\n";
    } else {
      print $fh "  <FlxbbDesign ncycles=1 name=design${num} constraints_sheet=10.0 constraints_NtoC=10.0 constraints_NtoC_dist=15 blueprint=\"$bbskel\" sfxn_relax=SFXN${num} task_operations=limitchi2,layer_all resfile=${resfile} filter_trial=1/>\n\n";
    }

    push ( @{$this->{movers}}, "design${num}" );

  }

  if( $init_close eq "close" ) {
    print $fh "</MOVERS>\n";
  }

}

##############################################################################################
sub protocols {

  my $this = shift;
  my ( $fh ) = @_;

  print $fh "\n<PROTOCOLS>\n\n";

  foreach my $m ( @{$this->{movers}} ) {
    print $fh "  < Add mover_name=$m />\n";
  }
  print $fh "\n</PROTOCOLS>\n\n";

}


1;
