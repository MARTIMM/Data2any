# Template for a translator module. All structures and method functions
# defined below are obligatory. Fill in the translatorname below at
# <translator name> and place the module in the Data2any directory.
#
# Any plugins for this translator must be stored at Data2any::<translator
# name>::*. Data2any will instanciate the translator by means of
# AppState::PluginManager.
#
package Data2any::<translator name>;

use Modern::Perl;
use version; our $VERSION = '' . version->parse('v0.0.1');
use 5.016003;

use namespace::autoclean;

use Moose;
use AppState;
require Data2any::Aux::GeneralTools;

extends 'Data2any::Aux::TranslatorTools';

#-------------------------------------------------------------------------------
# 
has _gtls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::GeneralTools'
    , default           => sub { return Data2any::Aux::GeneralTools->new; }
    );

has data2any =>
    ( is                => 'ro'
    , isa               => 'Data2any'
    , writer            => '_set_data2any'
    );


#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    AppState->instance->log_init('...');

    # Error codes
    #
    $self->code_reset;
#    $self->const( '',qw(M_INFO M_SUCCESS));

#    $self->const( '',qw(M_ERROR M_FAIL));

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub init
{
  my( $self, $data2any) = @_;

  $self->_set_data2any($data2any);
}

#-------------------------------------------------------------------------------
#
sub preprocess
{
  my( $self, $root) = @_;

  my $data2any = $self->data2any;

  # Prepare the traversal process. Other codes are C_NT_DEPTHFIRST1,
  # C_NT_BREADTHFIRST1 and C_NT_BREADTHFIRST2
  #
  my $nt = AppState->instance->get_app_object('NodeTree');
  $data2any->traverse_type($nt->C_NT_DEPTHFIRST2);

  # Each handler will be called with the following arguments but the user is
  # free to give any number of arguments
  #
  # - this translator object($self)
  # - data2any object
  # - node object of which there are several types
  #
  # The following handlers are needed for C_NT_DEPTHFIRST2
  #
  $data2any->node_handler_up(sub{ $self->goingUpHandler( $data2any, @_); });
  $data2any->node_handler_down(sub{ $self->goingDownHandler( $data2any, @_); });
  $data2any->node_handler_end(sub{ $self->atTheEndHandler( $data2any, @_); });
}

#-------------------------------------------------------------------------------
#
sub goingUpHandler
{
  my( $self, $node) = @_;

  my $data2any = $self->data2any;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top nodes.
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
  }
}

#-------------------------------------------------------------------------------
#
sub goingDownHandler
{
  my( $self, $node) = @_;

  my $data2any = $self->data2any;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top nodes.
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
  }
}

#-------------------------------------------------------------------------------
#
sub atTheEndHandler
{
  my( $self, $node) = @_;

  my $data2any = $self->data2any;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top root.
  }

  elsif( ref($node) eq 'AppState::NodeTree::NodeText' )
  {
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
  }
}

#-------------------------------------------------------------------------------
#
sub postprocess
{
  my($self) = @_;

  my $data2any = $self->data2any;
}

#-------------------------------------------------------------------------------
#
sub process_nodetree
{
  my($self) = @_;

  my $data2any = $self->data2any;
}

#-------------------------------------------------------------------------------

1;
