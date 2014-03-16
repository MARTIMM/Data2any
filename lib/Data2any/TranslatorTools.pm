package Data2any::TranslatorTools;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use version; our $VERSION = '' . version->parse("v0.5.1");
use 5.012000;

#-------------------------------------------------------------------------------
use Moose;

extends qw(AppState::Ext::Constants);

use AppState;

use Parse::RecDescent;
$::RD_HINT = 1;
my $toolsAddress = sub { return ''; };

#-------------------------------------------------------------------------------
#
has version =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => $VERSION
    );

# Filename and its type with data which must be translated to xml.
#
has inputFile =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'hasInputFile'
    , writer            => 'setInputFile'
    );

has dataFileType =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'Yaml'
    , writer            => 'setDataFileType'
    );

# Data in memory to be translated to xml. This is to have another way
# to give the data
#
has inputData =>
    ( is                => 'ro'
    , isa               => 'Any'
    , predicate         => 'hasInputData'
    , writer            => 'setInputData'
    );

# Label to store the data from inputFile or inputData with.
#
has dataLabel =>
    ( is                => 'ro'
    , isa               => 'Str'
    , predicate         => 'hasDataLabel'
    , writer            => 'setDataLabel'
    , default           => 'internal'
    );

has dropPreviousConfig =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    );

has requestDocument =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 0
    );

has parser =>
    ( is                => 'ro'
    , isa               => 'Parse::RecDescent'
    , default           =>
      sub
      {
        my($self) = @_;
        $Data2xml::Tools::toolsAddress = $self;

        my $grammar =<<'EOGRAMMAR';

                { my( @ids, @text, @pieces, $inQuote);
                  $inQuote = 0;
                  @text = ();
#say STDERR "Arg: $Data2xml::Tools::toolsAddress";
                }

# Start parsing here. Begin with skipping nothing and initialize some variables.
# Then process the 'textItems' production. When that parses ok, return the
# resulting text as an array reference to the caller.
#
textInit:       <skip: ''>
                {
                  $inQuote = 0;
                  @text = ();
                  1;
                }

                textItems
                {
                  $return = \@text;

                  1;
                }

# Try shortCut1, word or other symbols zero, one or more times
#
textItems:      (shortCut1 | word | otherSymbols)(s?)

# Shortcut1: id[text], Test for id and look in advance for the beginning bracket
#
shortCut1:      id ... '['
                {
                  if( $item[1] )
                  {
                    my $id = $item[1];
                    push @ids, $item[1];

                    # Pushing a reference => create new array and push ref of it
                    #
                    my @pt = @text;
                    push @pieces, \@pt;
                    @text = ();

                    1;
                  }

                  else
                  {
                    undef;
                  }
                }

                # The brackets and the content. The content is something which
                # is the same as at the start. This will introduce nesting.
                #
                '[' textItems ']'
                {
                  my $id = pop @ids;
                  my $t = pop @pieces;
                  if( join( '', @text) )
                  {
#                   push @$t, "<$id>", @text, "</$id>";
                    push @$t
                       , $Data2xml::Tools::toolsAddress->rewriteShortcut
                                           ( $id
                                           , @text
                                           );
#say STDERR "RW 1: ", $Data2xml::Tools::toolsAddress->rewriteShortcut( $id, @text);
                  }

                  else
                  {
#                   push @$t, "<$id />";
                    push @$t
                       , $Data2xml::Tools::toolsAddress->rewriteShortcut($id)
                       ;
#say STDERR "RW 2: ", $Data2xml::Tools::toolsAddress->rewriteShortcut( $id, @text);
                  }

                  @text = @$t;

                  1;
                }

# Test for the id. All letters and digits(exept for the first character) with
# the following characters '_', ':' and '-'.
#
id:             /[A-Za-z\_\:\-][A-Za-z0-9\_\:\-]*/
                {
                  $return = $item[1];
                  1;
                }

# A word is anything but brackets and spaces.
#
word:           /[^\[\]\s]+/
                {
                  push @text, $item[1];
                  1;
                }

                # When there is a bracket following a non-word, treat this as
                # just text.
                | '['
                {
                  push @text, '[';
                  1;
                }

                # Start all over to process the rest
                #
                textItems ']'
                {
                  push @text, ']';
                  1;
                }

otherSymbols:   /[ \t\n\r\(\)]+/
                {
                  push @text, $item[1];
                  1;
                }

EOGRAMMAR

        return Parse::RecDescent->new($grammar);
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('TLS');

  if( $self->meta->is_mutable )
  {
    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_DOCSELECTED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_CONFADDDED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_INPUTFILESELECTED',qw(M_INFO M_SUCCESS));
#    $self->const( '',qw(M_INFO M_SUCCESS));

    $self->const( 'C_NOPROCESS',qw(M_WARNING M_FORCED));
    $self->const( 'C_NODENOTCREATED',qw(M_ERROR M_FAIL));
    $self->const( 'C_CONFADDFAIL',qw(M_ERROR M_FAIL));
    $self->const( 'C_FILENOTDEFINED',qw(M_ERROR M_FAIL));
    $self->const( 'C_SELECTFAIL',qw(M_ERROR M_FAIL));
    $self->const( 'C_DOCNBRNOTFOUND',qw(M_WARNING M_FORCED));
#    $self->const( '',qw(M_ERROR M_FAIL));
#say "Tr Tools: $self";

    __PACKAGE__->meta->make_immutable;
  }
}

################################################################################
#
sub extendNodeTree
{
  my( $self, $rawData) = @_;

  # Get NodeTree object
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Build the tree from the raw data at the document root into a nodetree
  #
  my $parentNode = $self->getDataItem('parentNode');
  $nt->convert_to_node_tree( $rawData, $parentNode);
}

################################################################################
# Load user representation of xml from memory. First add a configuration
# specification of the users input file. Then select and set the configuration.
#
sub loadData
{
  my($self) = @_;

  my $label = 'D2X-' . $self->dataLabel;
  $self->setDataLabel($label);

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  my $log = $app->get_app_object('Log');

  # Check if the user wants the previous data destroyed
  #
  $cfg->drop_config_object($label)
    if defined $self->dropPreviousConfig
    and $self->dropPreviousConfig
    and $cfg->hasConfigObject($label)
    ;


  my $docNbr = $self->requestDocument;
  my $docType = 'data';
  $docNbr //= 0;

  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->checkAndSelectDocNbr($docNbr);
    $self->_log( "$docType to xml config '$label doc $docNbr selected"
               , $self->C_DOCSELECTED
               );
  }

  else
  {
    $cfg->add_config_object( $label
                           , { location => $self->C_CFF_FILEPATH
                             , requestFile => $label
                             }
                           );
    if( $log->is_last_succes )
    {
#       $cfg->load;
      $self->checkAndSelectDocNbr($docNbr);
      $self->_log( "Adding new data2xml config '$label', doc $docNbr selected"
                 , $self->C_DOCSELECTED
                 );
    }

    else
    {
      $self->_log( "Failed to add data2any config '$label'"
                 , $self->C_CONFADDFAIL
                 );
    }

    # Set the given data in the configuration
    #
    $cfg->setDocuments($self->inputData);
  }
}

################################################################################
# Load user representation of xml from any location. First add a configuration
# specification of the users input file. Then select and load the configuration.
# The data is saved and the next time this data is used ignoring the filename
# and config type.
#
sub loadInputFile
{
  my($self) = @_;

  my $filename = $self->inputFile;
  if( defined $filename and $filename )
  {
    my $docNbr = $self->requestDocument;
    my $docType = $self->dataFileType;

    my $label = 'D2X-' . $filename;
    $self->setDataLabel($label);
#say STDERR "Label: $label";

    my $app = AppState->instance;
    my $cfg = $app->get_app_object('ConfigManager');
    my $log = $app->get_app_object('Log');

    $docNbr //= 0;
    $docType //= 'Yaml';

    # Config is named like so "D2X-$filename". Now it is possible to convert
    # more files in several calls. When found, original settings will not be
    # changed. Only document is used to select document.
    #
    if( $cfg->hasConfigObject($label) )
    {
      $cfg->select_config_object($label);
      $self->checkAndSelectDocNbr($docNbr);
      $self->_log( "$docType to xml config '$label' doc $docNbr selected"
                 , $self->C_DOCSELECTED
                 );
    }

    else
    {
      $cfg->add_config_object( $label
                             , { location => $self->C_CFF_FILEPATH
                               , requestFile => $filename
                               , store_type => $docType
                               }
                             );
      if( $log->is_last_success )
      {
        $cfg->load;
        $self->checkAndSelectDocNbr($docNbr);
        $self->_log( "Adding new data2xml config '$label', doc $docNbr selected"
                   , $self->C_CONFADDDED
                   );
      }

      else
      {
        $self->_log( "Failed to add data2xml config '$label'"
                   , $self->C_CONFADDFAIL
                   );
      }
    }
  }

  else
  {
    $self->_log( "filename not defined", $self->C_FILENOTDEFINED);
  }
}

################################################################################
# Load user data representation of xml from any location. First add a
# configuration specification of the users input file. Then select
# and load the configuration.
#
sub selectInputFile
{
  my( $self, $docNbr) = @_;

  my $label = $self->dataLabel;
  my $cfg = AppState->instance->get_app_object('ConfigManager');
  $docNbr //= 0;

#say STDERR "SIF: Label: $label";
  if( $cfg->hasConfigObject($label) )
  {
    $cfg->select_config_object($label);
    $self->checkAndSelectDocNbr($docNbr);
    $self->_log( "data to config '$label', doc $docNbr selected"
               , $self->C_INPUTFILESELECTED
               );
  }

  else
  {
    $self->_log( "Failed to select data to xml config '$label'"
               , $self->C_SELECTFAIL
               );
  }

  return $cfg->get_current_document;
}

################################################################################
#
sub checkAndSelectDocNbr
{
  my( $self, $docNbr) = @_;

  my $app = AppState->instance;
  my $cfg = $app->get_app_object('ConfigManager');
  $cfg->select_document($docNbr);
  if( $cfg->get_current_document != $docNbr )
  {
    $self->_log( "Requested document not in range, set to"
               . $cfg->get_current_document
               , $self->C_DOCNBRNOTFOUND
               );
  }

  else
  {
    $self->_log( "doc $docNbr selected", $self->C_DOCSELECTED);
  }
}

################################################################################
#
sub getDefaultAttributes
{
  my($self) = @_;

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  my $yd = $self->getDataItem('nodeData');
  my $attr = {};

  $attr->{id} = $yd->{id} if $yd->{id};
  $attr->{class} = $yd->{class} if $yd->{class};
#  $attr->{name} = $yd->{name} if $yd->{name};

  return $attr;
}

################################################################################
#
sub setDefaultAttributes
{
  my( $self, $node, $idPrefix) = @_;

  my $yd = $self->getDataItem('nodeData');
  my $attr = {};
  $idPrefix //= '';

  $node->addAttr(id => $yd->{id} . "_$idPrefix") if $yd->{id};
  $node->addAttr(class => $yd->{class}) if $yd->{class};
#  $node->addAttr(name => $yd->{name} . "_$idPrefix") if $yd->{name};
}

################################################################################
#
sub getDollarVar
{
  my( $self, $key) = @_;

  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#say STDERR "Get KV: $tbd, $key = ", $tbd->{dollarVariables}{$key};
  return $tbd->{dollarVariables}{$key};
}

################################################################################
#
sub setDollarVar
{
  my( $self, %kvPairs) = @_;

  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
#say STDERR "Tbd: $tbd";
  foreach my $key (keys %kvPairs)
  {
#say STDERR "Set KV: $key, $kvPairs{$key}";
    $tbd->{dollarVariables}{$key} = $kvPairs{$key};
  }
}

################################################################################
#
sub getDVarNames
{
  my( $self) = @_;
  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
  return (keys %{$tbd->{dollarVariables}});
}

################################################################################
#
sub clearDVars
{
  my( $self) = @_;
  my $tbd = AppState->instance->get_app_object('NodeTree')->tree_build_data;
  $tbd->{dollarVariables} = {};
}

#-------------------------------------------------------------------------------

1;
