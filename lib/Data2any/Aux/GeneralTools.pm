package Data2any::Aux::GeneralTools;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use version; our $VERSION = '' . version->parse("v0.0.4");
use 5.012000;

#-------------------------------------------------------------------------------
use Moose;

extends qw(AppState::Plugins::Log::Constants);

use AppState;
use AppState::Plugins::Log::Meta_Constants;
use AppState::Plugins::NodeTree::NodeGlobal;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_DOCSELECTED',       'M_INFO', '%s to xml config %s doc %s selected');
def_sts( 'C_CONFADDDED',        'M_INFO', 'Adding new data2xml config %s, doc %s selected');
def_sts( 'C_INPUTFILESELECTED', 'M_INFO', 'data to config %s, doc %s selected');
def_sts( 'C_FILENOTDEFINED',    'M_ERROR', 'filename not defined');
def_sts( 'C_CONFADDFAIL',       'M_ERROR', 'Failed to add data2xml config %s');
def_sts( 'C_SELECTFAIL',        'M_ERROR', 'Failed to select data to xml config %s');
def_sts( 'C_DOCNBRNOTFOUND',    'M_WARN', 'Requested document not in range, set to %s');

#-------------------------------------------------------------------------------
# Filename and its type with data which must be translated to xml.
#
has input_file =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'has_input_file'
    , writer            => 'set_input_file'
    );

has data_file_type =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'Yaml'
    , writer            => 'set_data_file_type'
    );

has request_document =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 0
    );

# Data in memory to be translated to xml. This is to have another way
# to give the data
#
has input_data =>
    ( is                => 'ro'
    , isa               => 'Any'
    , predicate         => 'has_input_data'
    , writer            => 'set_input_data'
    );

# Label to store the data from input_file or input_data with.
#
has data_label =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'has_data_label'
    , writer            => 'set_data_label'
    , default           => 'internal'
    );

has drop_previous_config =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('.GT');

}

################################################################################
# Load user representation of xml from any location. First add a configuration
# specification of the users input file. Then select and load the configuration.
# The data is saved and the next time this data is used ignoring the filename
# and config type.
#
sub load_input_file
{
  my($self) = @_;

  my $filename = $self->input_file;
  if( defined $filename and $filename )
  {
    my $docNbr = $self->request_document;
    my $docType = $self->data_file_type;

    my $label = 'D2A-' . $filename;
    $self->set_data_label($label);
#say STDERR "Label: $label";

    my $app = AppState->instance;
    my $cfg = $app->get_app_object('ConfigManager');
    my $log = $app->get_app_object('Log');

    $docNbr //= 0;
    $docType //= 'Yaml';

    # Config is named like so "D2A-$filename". Now it is possible to convert
    # more files in several calls. When found, original settings will not be
    # changed. Only document is used to select document.
    #
    if( $cfg->has_config_object($label) )
    {
      $cfg->select_config_object($label);
      $self->check_and_select_doc_nbr($docNbr);
      $self->log( $self->C_DOCSELECTED, [ $docType, $label, $docNbr]);
    }

    else
    {
      $cfg->add_config_object( $label
                             , { location => $cfg->C_CFF_FILEPATH
                               , request_file => $filename
                               , store_type => $docType
                               }
                             );
      if( $log->is_last_success )
      {
        $cfg->load;
        $self->check_and_select_doc_nbr($docNbr);
        $self->log( $self->C_CONFADDDED, [ $label, $docNbr]);
      }

      else
      {
        $self->log( $self->C_CONFADDFAIL, [$label]);
      }
    }
  }

  else
  {
    $self->log($self->C_FILENOTDEFINED);
  }
}

################################################################################
# Load user representation of xml from memory. First add a configuration
# specification of the users input file. Then select and set the configuration.
#
sub load_data
{
  my($self) = @_;

  my $label = 'D2A-' . $self->data_label;
  $self->set_data_label($label);

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  my $log = $app->get_app_object('Log');

  # Check if the user wants the previous data destroyed
  #
  $cfg->drop_config_object($label)
    if defined $self->drop_previous_config
    and $self->drop_previous_config
    and $cfg->has_config_object($label)
    ;


  my $docNbr = $self->request_document;
  my $docType = 'data';
  $docNbr //= 0;

  if( $cfg->has_config_object($label) )
  {
    $cfg->select_config_object($label);
    $self->check_and_select_doc_nbr($docNbr);
    $self->log( $self->C_DOCSELECTED, [ $docType, $label, $docNbr]);
  }

  else
  {
    $cfg->add_config_object( $label
                           , { location => $cfg->C_CFF_FILEPATH
                             , request_file => $label
                             }
                           );
    if( $log->is_last_success )
    {
      $self->check_and_select_doc_nbr($docNbr);
      $self->log( $self->C_DOCSELECTED, [ $docType, $label, $docNbr]);
    }

    else
    {
      $self->log( $self->C_CONFADDFAIL, [$label]);
    }

    # Set the given data in the configuration
    #
    $cfg->setDocuments($self->_gtls->input_data);
  }
}

################################################################################
# Load user data representation of xml from any location. First add a
# configuration specification of the users input file. Then select
# and load the configuration.
#
sub select_input_file
{
  my( $self, $docNbr) = @_;

  my $label = $self->data_label;
  my $cfg = AppState->instance->get_app_object('ConfigManager');
  $docNbr //= 0;

  if( $cfg->has_config_object($label) )
  {
    $cfg->select_config_object($label);
    $self->check_and_select_doc_nbr($docNbr);
    $self->log( $self->C_INPUTFILESELECTED, [$label, $docNbr]);
  }

  else
  {
    $self->log( $self->C_SELECTFAIL, [$label]);
  }

  return $cfg->get_current_document;
}

################################################################################
#
sub check_and_select_doc_nbr
{
  my( $self, $docNbr) = @_;

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  $cfg->select_document($docNbr);
  if( $cfg->get_current_document != $docNbr )
  {
    $self->log( $self->C_DOCNBRNOTFOUND, [$cfg->get_current_document]);
  }

  else
  {
    my $docType = $self->data_file_type;
    my $label = 'D2A-' . $self->input_file;
    $self->log( $self->C_DOCSELECTED, [ $docType, $label, $docNbr]);
  }
}

################################################################################
#
sub get_variable
{
  my( $self, $key) = @_;

  # Variables in the Data2any distribution start with a dollar. Remove the
  # '$' on front if there is still one.
  #
  $key =~ s/^\$//;
  my $node_global = AppState::Plugins::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data($key);
}

################################################################################
# !!!!!!!!!!!!!!! Aanpassen !!!!!!!!!!!
sub get_variables
{
  my( $self, $key) = @_;

  # Variables in the Data2any distribution start with a dollar. Remove the
  # '$' on front if there is still one.
  #
  $key =~ s/^\$//;
  my $node_global = AppState::Plugins::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data($key);
}

################################################################################
# Store the data in a field in the node global data. Any node can reach this
#
sub set_variables
{
  my( $self, %kvPairs) = @_;

  my $node_global = AppState::Plugins::NodeTree::NodeGlobal->instance;
  $node_global->set_global_data(%kvPairs);
}

################################################################################
#
sub get_dvar_names
{
  my( $self) = @_;

  my $node_global = AppState::Plugins::NodeTree::NodeGlobal->instance;
  return $node_global->get_global_data_keys;
}

################################################################################
#
sub clear_dvars
{
  my( $self) = @_;
return;

  my $node_global = AppState::Plugins::NodeTree::NodeGlobal->instance;
  $node_global->clear_global_data;
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;
