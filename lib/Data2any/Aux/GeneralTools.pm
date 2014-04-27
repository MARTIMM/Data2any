package Data2any::Aux::GeneralTools;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use version; our $VERSION = '' . version->parse("v0.0.1");
use 5.012000;

#-------------------------------------------------------------------------------
use Moose;

extends qw(AppState::Ext::Constants);

use AppState;

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('.GT');

  if( $self->meta->is_mutable )
  {
    # Error codes
    #
    $self->code_reset;
#    $self->const( '',qw(M_INFO M_SUCCESS));

#    $self->const( '',qw(M_ERROR M_FAIL));

    __PACKAGE__->meta->make_immutable;
  }
}

################################################################################
#
sub get_dollar_var
{
  my( $self, $key) = @_;

  # Variables in the Data2any distribution start with a dollar. Remove the
  # '$' on front if there is still one.
  #
  $key =~ s/^\$//;
  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data($key);
}

################################################################################
# Store the data in a field in the node global data. Any node can reach this
#
sub set_dollar_var
{
  my( $self, %kvPairs) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  $node_global->set_global_data(%kvPairs);

#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  foreach my $key (keys %kvPairs)
#  {
#    $tbd->{dollarVariables}{$key} = $kvPairs{$key};
#  }
}

################################################################################
#
sub get_dvar_names
{
  my( $self) = @_;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data_keys;
  
#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  return (keys %{$tbd->{dollarVariables}});
}

################################################################################
#
sub clear_dvars
{
  my( $self) = @_;
return;

  my $node_global = AppState::NodeTree::NodeGlobal->instance;
  $node_global->clear_global_data;

#  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#  $tbd->{dollarVariables} = {};
}

#-------------------------------------------------------------------------------

1;
