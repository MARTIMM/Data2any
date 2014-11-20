package Data2any;

use version; our $VERSION = '' . version->parse('v0.1.4');
use 5.016003;

use Modern::Perl;

use namespace::autoclean;
#use utf8;
#use feature 'unicode_strings';

#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use Moose;
use Moose::Util::TypeConstraints;
require match::simple;

extends qw(AppState::Plugins::Log::Constants);
require Data2any::Aux::GeneralTools;

use AppState;
use AppState::Plugins::Log::Meta_Constants;

require Cwd;
require File::Basename;
require File::HomeDir;
require File::Path;

use DateTime;
#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_TRANSLATORSET',   'M_INFO', "Translator set to '%s'");
def_sts( 'C_CONFLOADED',      'M_TRACE', 'Configuration file loaded');
def_sts( 'C_DATALOADED',      'M_TRACE', 'User data loaded');
def_sts( 'C_CANNOTRUNSUB',    'M_WARNING', 'Cannot run subroutine %s()');
def_sts( 'C_FAILMODCONF',     'M_ERROR', 'Error modifying default config');
def_sts( 'C_NOINPUTFILE',     'M_ERROR', 'One of the options input_data with data_label or input_file is missing');
def_sts( 'C_ROOTNOARRAY',     'M_ERROR', 'Root is not an array reference');
def_sts( 'C_NODEFAULTCFGOBJ', 'M_ERROR', 'No default config object');

#-------------------------------------------------------------------------------
# General tools
#
has _gtls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::GeneralTools'
    , default           => sub { return Data2any::Aux::GeneralTools->new; }
    , handles           => [qw( set_variables input_file data_file_type
                                request_document
                              )
                           ]
    );

# Translator
#
has _translators =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::PluginManager'
    , init_arg          => undef
    , default           =>
      sub
      {
        my($self) = @_;

        my $pm = AppState->instance->get_app_object('PluginManager');
        my $path = Cwd::realpath($INC{"Data2any.pm"});
        $path =~ s@/Data2any.pm@@;
#say STDERR "TR: $path";

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                             , max_depth => 3
                             , search_regex => qr@/Data2any/[A-Z][\w]+.pm$@
                             , api_test => [ qw( init preprocess postprocess
                                               )
                                           ]
                             }
                           );

#$pm->list_plugin_names;

        $self->_translatorTypes([$pm->get_plugin_names]);
        return $pm;
      }
    );

# Possible translator types. This is set by the plugin manager default
# initialization. Need to use non-moose variable because of test in subtype
# can not use $self to use a getter such as $self->translatorTypes().
#
my $__translatorTypes__ = [];
has translatorTypes =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , init_arg          => undef
    , writer            => '_translatorTypes'
    , default           => sub { return []; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $__translatorTypes__ = $n;
      }
    );

# Subtype to be used to test translatorType against.
#
subtype 'Data2any::TranslatorType'
    => as 'Str'
    => where { match::simple::match( $_, $__translatorTypes__) }
    => message { "The translator type '$_' is not correct" };


# Type of translator plugin used.
#
has translator =>
    ( is                => 'rw'
    , isa               => 'Data2any::TranslatorType'
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $o //= '';
        if( $n ne $o )
        {
          $self->log( $self->C_TRANSLATORSET, [$n]);
        }
      }
    );

has topRawEntries =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , predicate         => 'hasTopEntries'
    , writer            => 'setTopEntries'
    );

has nodeTree =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::NodeTree::NodeDOM'
    , writer            => 'setNodeTree'
    );

has properties =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , traits            => ['Hash']
    , handles           =>
      { setProperty     => 'set'
      , getProperty     => 'get'
      , getProperties   => 'keys'
      }
    );

# Select keyword of the SendTo control. STDOUT is reserved to send result to
# standard output and NOOUT is used to inhibit any output. The default will be
# STDOUT. If no SendTo is defined, output will also go to STDOUT.
#
has sendToSelect =>
    ( is                => 'rw'
    , isa               => 'Any'
    , default           => 'STDOUT'
    );

################################################################################
#
sub BUILD
{
  my( $self, $options) = @_;

  $self->_gtls->set_input_file($options->{input_file} // '--No Defined Filename--.txt');
  $self->_gtls->set_data_file_type($options->{data_file_type} // 'Yaml');

  $self->log_init('D2A');

  if( !$self->can('traverse_type') )
  {
    my $meta = Class::MOP::Class->initialize(__PACKAGE__);
    $meta->make_mutable;

    # Code is a dualvar => type is 'Any' instead of 'Int'.
    #
    my $nt = AppState->instance->get_app_object('NodeTree');
    $self->meta->add_attribute( 'traverse_type'
                              , default         => $nt->C_NT_DEPTHFIRST2
                              , init_arg        => undef
                              , is              => 'rw'
                              , isa             => 'Any'
                              );
  
    $meta->make_immutable;
  }
}

################################################################################
# Steps to convert data to a nodetree
#
sub nodetreeFromData
{
  my($self) = @_;

  $self->_initialize;
  $self->_preprocess;
  $self->_processTree;
}

################################################################################
# Initialize variables, load and modify program config and read users file
#
sub _initialize
{
  my($self) = @_;

  # Initialize
  #
  my $app = AppState->instance;
  my $log = $app->get_app_object('Log');

  # Load and save programs configuration if not existent. When there where no
  # documents, make one too. Name will be ~/.<programname>/data2any.yml.
  #
  my $cfg = $app->get_app_object('ConfigManager');
  $cfg->modify_config_object( 'defaultConfigObject'
                            , {request_file => 'data2any'}
                            );
  $self->log($self->C_FAILMODCONF) unless $log->is_last_success;
  $cfg->load;
  $cfg->add_documents({}) unless $cfg->nbr_documents;
  $cfg->save unless -e $cfg->config_file;

#say "D2a i: $self";
  $self->log($self->C_CONFLOADED);

  #-----------------------------------------------------------------------------
  # Add and select data2xml config and select also requested document.
  #
  if( $self->_gtls->has_input_data and $self->_gtls->has_data_label )
  {
    $self->_gtls->load_data;
  }

  elsif( $self->_gtls->has_input_file )
  {
    $self->_gtls->load_input_file;
  }

  else
  {
    $self->log($self->C_NOINPUTFILE);
  }

  # Check if the root is an array reference.
  #
  $self->log($self->C_ROOTNOARRAY) unless ref $cfg->get_document eq 'ARRAY';

  # Make an entry in the configfile recently loaded files.
  #
  my $userFilePath = $cfg->config_file;
  $cfg->select_config_object('defaultConfigObject');
  if( $log->is_last_success )
  {
    my $date = DateTime->now;
    $cfg->select_document(0);
    $cfg->set_kvalue( '/recently/loaded', $userFilePath
                    , $date->ymd . ' ' . $date->hms
                    );

#    $self->_dtls->clear_dvars;
    $self->_gtls->set_variables( file => $userFilePath, date => $date->ymd
                                , time => $date->hms
                                , version_Data2any => $VERSION
                                );
    $cfg->save;

    $self->log($self->C_DATALOADED);
  }

  else
  {
    $self->log($self->C_NODEFAULTCFGOBJ);
  }
}

################################################################################
# Initialize variables, load and modify program config and read users file
# Get all properties
#
sub _preprocess
{
  my($self) = @_;

  $self->_gtls->select_input_file($self->_gtls->request_document);
  my $cfg = AppState->instance->get_app_object('ConfigManager');
  my $root = $cfg->get_document;

  #-----------------------------------------------------------------------------
  # Work through all properties and store them into a hash. This means all
  # properties should be unique.
  #
  my $documentEntries = [];
  foreach my $propertySet (@$root)
  {
    my $DocumentControlKeyFound = 0;

    # On the top level there may be a key 'DocumentControl' which does not
    # belong to the document. When found get all properties defined there
    # and store in the properties hash.
    #
    foreach my $k (keys %$propertySet)
    {
      if( $k =~ m/^DocumentControl/
      and defined $propertySet->{DocumentControl}
        )
      {
        $DocumentControlKeyFound = 1;
        $self->properties($propertySet->{DocumentControl});
        last;
      }
    }

    # When key is not the DocumentControl key then store it whith the document
    #
    push @$documentEntries, $propertySet unless $DocumentControlKeyFound;
  }

  # Take the slice and store the top raw entries of the later to be created
  # node tree.
  #
  $self->setTopEntries($documentEntries);

  #-----------------------------------------------------------------------------
  # Check encoding. If not defined, use UTF-8.
  #
  my $encoding = $self->getProperty('Encoding') // 'UTF-8';
  $self->setProperty( 'Encoding', $encoding);
  $self->_gtls->set_variables( 'Encoding' => $encoding);

  #-----------------------------------------------------------------------------
  # Get the translator type from the DocumentControl section if any
  #
  my $tr = $self->getProperty('Translator');
  $self->translator($tr) if defined $tr and $tr;

  #-----------------------------------------------------------------------------
  # Initialize translator
  #
  my $trobj = $self->get_translator_object;
  if( $trobj->can('init') )
  {
    $trobj->init($self);
  }

  else
  {
    $self->log( $self->C_CANNOTRUNSUB, ['init']);
  }

  #-----------------------------------------------------------------------------
  # Let the translator preprocess some stuff
  #
  if( $trobj->can('preprocess') )
  {
    $trobj->preprocess($root);
  }

  else
  {
    $self->log( $self->C_CANNOTRUNSUB, ['preprocess']);
  }

  # Get variables from the DocumentControl section
  #
  if( defined $self->getProperty('SetVariables') )
  {
    my $dvs = $self->getProperty('SetVariables');
    $self->_gtls->set_variables(%$dvs) if ref $dvs eq 'HASH';
  }
}

################################################################################
#
sub node_handler
{
  my( $self, $code) = @_;

  my $nt = AppState->instance->get_app_object('NodeTree');
  $nt->node_handler($code);
}

################################################################################
#
sub node_handler_up
{
  my( $self, $code) = @_;

  my $nt = AppState->instance->get_app_object('NodeTree');
  $nt->node_handler_up($code);
}

################################################################################
#
sub node_handler_down
{
  my( $self, $code) = @_;

  my $nt = AppState->instance->get_app_object('NodeTree');
  $nt->node_handler_down($code);
}

################################################################################
#
sub node_handler_end
{
  my( $self, $code) = @_;

  my $nt = AppState->instance->get_app_object('NodeTree');
  $nt->node_handler_end($code);
}

################################################################################
#
sub _processTree
{
  my( $self) = @_;

  my $topRawEntries = $self->topRawEntries;

  # Get NodeTree object and the treebuild data hash. This is the hash which
  # is available to the plugins when they are created and called for action
  # via the process() function.
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Define some variables to be used when nodetree is build
  #
  $self->_gtls->set_variables
         ( input_file                   => $self->_gtls->input_file
         , data_file_type               => $self->_gtls->data_file_type
         , input_data                   => $self->_gtls->input_data
         , data_label                   => $self->_gtls->data_label
         , request_document             => $self->_gtls->request_document
         );

  # Build the tree from the raw data at the document root into a nodetree
  # First set some information which can be read when the tree is build.
  #
  # Convert the data into a node tree.
  #
  my $node_tree = $nt->convert_to_node_tree($topRawEntries);

  # Save the node tree
  #
  $self->setNodeTree($node_tree);
}

################################################################################
#
sub transform_nodetree
{
  my( $self) = @_;

  # Get NodeTree object
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Traverse the tree. First setup of handlers then traverse depth
  # first method 2.
  #
#  my $level = 0;
#  my $xmlResult = '';

#  $self->clearTTD;
  my $traverseType = $self->traverse_type;
  $nt->traverse( $self->nodeTree, $traverseType);
}

################################################################################
#
sub postprocess
{
  my( $self) = @_;

  my $trobj = $self->get_translator_object;
  my $resultText;
  if( $trobj->can('postprocess') )
  {
    $resultText = $trobj->postprocess;
  }

  else
  {
    $resultText = '';
    $self->log( $self->C_CANNOTRUNSUB, ['postprocess']);
  }

  $resultText //= '';

  #-----------------------------------------------------------------------------
  # Send result away except when NOOUT is requested. When NOOUT is used for
  # SendToSelect, the caller might want to use the result in some other way.
  #
  if( $self->sendToSelect ne 'NOOUT' and $resultText )
  {
    # Get the input filename or data label to get the path to the file.
    # Get the basename from it.
    #
    my $ifile = $self->_gtls->input_file || $self->_gtls->data_label;
    my( $basename, $directories, $suffix)
       = File::Basename::fileparse( $ifile, qr/\.[^.]*$/);

    my $sendTo;
    my $sendToSpec = $self->getProperty('SendTo');

    # Check several types of SendTo selections in combination with
    # SendTo descriptions. SendTo selection NOOUT is already tested above.
    #
    # Check if there is a SendTo description. If not, send to STDOUT.
    #
    if( !defined $sendToSpec )
    {
      $sendTo = '>-';
    }

    # When the SendTo definition is an array, then the SendTo selection must be
    # a number bigger then or equal to zero. If the SendTo selection is out of
    # range or text (like the default 'STDOUT') the first one is selected.
    #
    elsif( ref $sendToSpec eq 'ARRAY' )
    {
      # Text and negative values are converted to the first entry 0
      #
      $self->sendToSelect(0) unless $self->sendToSelect =~ m/^\d+$/;

      my $nbrSpecs = scalar(@$sendToSpec);
      $sendTo = $self->sendToSelect < $nbrSpecs
                  ? $sendToSpec->[$self->sendToSelect]
                  : $sendToSpec->[0]
                  ;
    }

    # When the SendTo definition is a HASH, then the SendTo selection must be
    # a text string. The keyname STDOUT is reserved to send to stdout. Also
    # when the key does not exist output will be send to stdout.
    #
    elsif( ref $sendToSpec eq 'HASH' )
    {
      # STDOUT or when the key in SendTo selection
      #
      if( $self->sendToSelect eq 'STDOUT'
          or !defined $sendToSpec->{$self->sendToSelect}
        )
      {
        $sendTo = '>-';
      }

      else
      {
        $sendTo = $sendToSpec->{$self->sendToSelect};
      }
    }

    # If the SendTo definition is a scalar, then the SendTo selection is
    # ignored.
    #
    elsif( $sendToSpec )
    {
      $sendTo = $sendToSpec;
    }

    $sendTo =~ s/__BASENAME__/$basename/g;
    $sendTo =~ s/\n/ /g;

    my $outputHandler;
    open $outputHandler, $sendTo;
    say $outputHandler $resultText;

    close $outputHandler;
  }
}

################################################################################
#
sub process_nodetree
{
  my( $self) = @_;

  my $trobj = $self->get_translator_object;
  if( $trobj->can('process_nodetree') )
  {
    $trobj->process_nodetree;
  }

  else
  {
    $self->log( $self->C_CANNOTRUNSUB, ['process_nodetree']);
  }
}

################################################################################
#
sub get_translator_object
{
  my( $self) = @_;

  return $self->_translators->get_object( { name => $self->translator});
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

Data2xml - Perl extension to convert a specially formatted data file into xml.


=head1 SYNOPSIS

=over 2

=item * Example 1, Program yaml2xml

  use Modern::Perl;
  require Data2xml;

  my $filename = shift @ARGV;
  my $yaml2xml = Data2xml->new( input_file => $filename
                              , data_file_type => 'Yaml'
                              , logging => 1
                              , request_document => 0
                              );
  $yaml2xml->nodetreeFromData;
  $yaml2xml->convert2xml;

=back

=over 2

=item * Example 2, Generate directly from data in memory

  use Modern::Perl;
  require Data2xml;

  my $data =
  [ [ { DOCTYPE => { root => 'html', type => 'public'}}
    , { 'html' =>
        [ { 'body' =>
            [ { h1 => 'This is the top'}
            , bless { type      => 'href'
                    , alttext   => 'file manager'
                    , image     => 'file_manager.png'
                    , reference => 'y2x2.yml'
                    }
                    , 'Data2xml::LinkFile'
            ]
          }
        ]
      }
    ]
  ];

  my $d2xml = Data2xml->new( input_data => $data
                           , data_label => 'internal'
                           , logging => 1
                           , request_document => 2
                           );

  $d2xml->nodetreeFromData;
  $d2xml->convert2xml;

=back


=head1 DESCRIPTION

Generate XML code from data. Example 1 is a short program called C<yaml2xml>
which is installed for your conveniance. This program reads a YAML datafile
after which it is converted to a nodetree with C<nodetreeFromData>. Then call
C<convert2xml> to generate the XML from the nodetree.


=head1 METHODS

=over 2

=item * new(%attributes).

=item * nodeTree().

=item * nodetreeFromData(). This method is used to gather data from memory
or from a file and create a nodetree from it. To get to this tree call
nodeTree().

=item * postprocess(). Add extra code to the xml like a xml declaration,
doctype, a http header or convert the whole into pdf.

=item * xmlFromNodetree(). Convert the nodetree to xml. Use resultText() to get
this text.


=back


=head1 SEE ALSO



=head1 AUTHOR

M. Timmerman, E<lt>mt1957@gmail.com<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by M. Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
