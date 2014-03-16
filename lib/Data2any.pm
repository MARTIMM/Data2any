package Data2any;

use Modern::Perl;
use namespace::autoclean;
#use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use version; our $VERSION = '' . version->parse('v0.1.0');
use 5.016003;

use Moose;
use Moose::Util::TypeConstraints;

extends qw(Data2any::Tools);

use AppState;
use AppState::Plugins::Feature::PluginManager;

require Cwd;
require File::Basename;
require File::HomeDir;
require File::Path;

use DateTime;

#-------------------------------------------------------------------------------
# Translator
#
has translators =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::Feature::PluginManager'
    , init_arg          => undef
    , default           =>
      sub
      {
        my($self) = @_;

        my $pm = AppState::Plugins::Feature::PluginManager->new;
        my $path = Cwd::realpath($INC{"Data2any.pm"});
        $path =~ s@/Data2any.pm@@;

        # Number of separators in the path is the depth of the base
        #
        my(@lseps) = $path =~ m@(/)@g;

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                            , depthSearch => 1 + @lseps
                            , searchRegex => qr@/Data2any/[A-Z][\w]+.pm$@
                            , apiTest => [ qw( init preprocess
                                               goingUpHandler goingDownHandler
                                               atTheEndHandler postprocess
                                             )
                                         ]
                            }
                          );
        $pm->drop_plugin('Tools');
        $pm->drop_plugin('TranslatorTools');
#$pm->listPluginNames;

        $self->_translatorTypes(join '|', $pm->get_plugin_names);
        return $pm;
      }
    );

# Possible translator types. This is set by the plugin manager default
# initialization. Need to use non-moose variable because of test in subtype
# can not use $self to use a getter such as $self->translatorTypes().
#
my $__translatorTypes__ = '';
has translatorTypes =>
    ( is                => 'ro'
    , isa               => 'Str'
    , init_arg          => undef
    , writer            => '_translatorTypes'
    , default           => ''
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
    => where { $_ =~ m/$__translatorTypes__/ }
    => message { "The translator type '$_' is not correct" };


# Type of translator plugin used.
#
has translator =>
    ( is                => 'rw'
    , isa               => 'Data2any::TranslatorType'
    , default           => 'Xml'
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $o //= '';
        if( $n ne $o )
        {
          $self->_log( "Translator set to $n", $self->C_TRANSLATORSET);
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
    , isa               => 'AppState::NodeTree::NodeDOM'
    , writer            => 'setNodeTree'
    );

has treeTraverseData =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { setTTD          => 'set'
      , getTTD          => 'get'
      , clearTTD        => 'clear'
      }
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

# Select keyword of the SendTo control. STDOUT is reserved to send xml result to
# standard output and NOOUT is used to inhibit any output. The default will be
# STDOUT. If no SendTo is defined, output will also go to STDOUT.
#
has sendToSelect =>
    ( is                => 'rw'
    , isa               => 'Any'
    , default           => 'STDOUT'
    );

has logging =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        return if defined $o and $n eq $o;

        my $log = AppState->instance->get_app_object('Log');
        return unless ref $log eq 'AppState::Log';

        if( $n eq 1 )
        {
          $log->log_mask($self->SEVERITY);
          $log->die_on_error(1);
#         $log->show_on_error(0);
          $log->show_on_warning(1);
          $log->do_append_log(0);

          $log->start_logging;
        }

        else
        {
          $log->stop_logging;
        }
      }
    );

################################################################################
#
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('D2A');

    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_TRANSLATORSET',    qw(M_INFO M_SUCCESS));
    $self->const( 'C_CONFLOADED',       qw(M_INFO M_SUCCESS));
    $self->const( 'C_DATALOADED',       qw(M_INFO M_SUCCESS));
#    $self->const( 'C_',qw(M_INFO M_SUCCESS));

    $self->const( 'C_FAILMODCONF',      qw(M_ERROR));
    $self->const( 'C_NOINPUTFILE',      qw(M_ERROR M_FAIL));
    $self->const( 'C_ROOTNOARRAY',      qw(M_ERROR M_FAIL));
    $self->const( 'C_NODEFAULTCFGOBJ',  qw(M_ERROR M_FAIL));
#    $self->const( 'C_',qw(M_ERROR M_FAIL));

    __PACKAGE__->meta->make_immutable;
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
                            , {requestFile => 'data2any'}
                            );
  $self->_log( "Error modifying default config", $self->C_FAILMODCONF)
    unless $log->is_last_success;
  $cfg->load;
  $cfg->addDocuments({}) unless $cfg->nbr_documents;
  $cfg->save unless -e $cfg->configFile;

#say "D2a i: $self";
  $self->_log( "Configuration file loaded", $self->C_CONFLOADED);

  #-----------------------------------------------------------------------------
  # Add and select data2xml config and select also requested document.
  #
  if( $self->hasInputData and $self->hasDataLabel )
  {
    $self->loadData;
  }

  elsif( $self->hasInputFile )
  {
    $self->loadInputFile;
  }

  else
  {
    $self->_log( 'One of the options inputData with dataLabel or'
               . ' inputFile is missing'
               , $self->C_NOINPUTFILE
               );
  }

  # Check if the root is an array reference.
  #
  $self->_log( 'Root is not an array reference', $self->C_ROOTNOARRAY)
     unless ref $cfg->get_document eq 'ARRAY';

  # Make an entry in the configfile recently loaded files.
  #
  my $userFilePath = $cfg->configFile;
  $cfg->select_config_object('defaultConfigObject');
  if( $log->is_last_success )
  {
    my $date = DateTime->now;
    $cfg->select_document(0);
    $cfg->set_kvalue( '/recently/loaded', $userFilePath
                    , $date->ymd . ' ' . $date->hms
                    );

    $self->clearDVars;
    $self->setDollarVar( file => $userFilePath, date => $date->ymd
                       , time => $date->hms, version_Data2xml => $VERSION
                       );
    $cfg->save;

    $self->_log( "User data loaded", $self->C_DATALOADED);
  }

  else
  {
    $self->_log( "User data loaded", $self->C_NODEFAULTCFGOBJ);
  }

  #-----------------------------------------------------------------------------
  # Initialize translator
  #
  my $trobj = $self->translators->get_object( { name => $self->translator});
  $trobj->init($self);
}

################################################################################
# Initialize variables, load and modify program config and read users file
# Get all properties
#
sub _preprocess
{
  my($self) = @_;

  my $trobj = $self->translators->get_object( { name => $self->translator});
  $self->selectInputFile($self->requestDocument);
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
      if( $k =~ m/^DocumentControl/ )
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
  # Get the translator type from the DocumentControl section if any
  #
  my $tr = $self->getProperty('Translator');
  $self->translator($tr) if defined $tr and $tr;

  #-----------------------------------------------------------------------------
  # Let the translator preprocess some stuff
  #
  $trobj->preprocess( $self, $root);
}

################################################################################
#
sub _processTree
{
  my( $self) = @_;

#  my $trobj = $self->translators->get_object( { name => $self->translator});
  my $topRawEntries = $self->topRawEntries;

  # Get NodeTree object and the treebuild data hash. This is the hash which
  # is available to the plugins when they are created and called for action
  # via the process() function.
  #
  my $nt = AppState->instance->get_app_object('NodeTree');
  my $tbd = $nt->tree_build_data;

  # Set information in this treebuild data for the plugins
  #
  $tbd->{inputFile} = $self->inputFile;
  $tbd->{dataFileType} = $self->dataFileType;
  $tbd->{inputData} = $self->inputData;
  $tbd->{dataLabel} = $self->dataLabel;
  $tbd->{requestDocument} = $self->requestDocument;

  # Define also some dollar variables to be used as $inputFile and so on
  #
  $self->setDollarVar( inputFile => $self->inputFile
                     , dataFileType => $self->dataFileType
                     , inputData => $self->inputData
                     , dataLabel => $self->dataLabel
                     , requestDocument => $self->requestDocument
                     );

  # Build the tree from the raw data at the document root into a nodetree
  # First set some information which can be read when the tree is build.
  #
  # Convert the data into a node tree.
  #
  $self->setNodeTree($nt->convert_to_node_tree($topRawEntries));
}

################################################################################
#
sub transformNodetree
{
  my( $self) = @_;

  # Get NodeTree object
  #
  my $nt = AppState->instance->get_app_object('NodeTree');

  # Traverse the tree. First setup of handlers then traverse depth
  # first method 2.
  #
  my $level = 0;
  my $xmlResult = '';

  my $trobj = $self->translators->get_object( { name => $self->translator});
  $nt->node_handler_up(sub{ $trobj->goingUpHandler( $self, @_); });
  $nt->node_handler_down(sub{ $trobj->goingDownHandler( $self, @_); });
  $nt->node_handler_end(sub{ $trobj->atTheEndHandler( $self, @_); });

  $self->clearTTD;
  $nt->traverse( $self->nodeTree, $nt->C_NT_DEPTHFIRST2);
}

################################################################################
#
sub postprocess
{
  my( $self) = @_;

  my $trobj = $self->translators->get_object( { name => $self->translator});
  $trobj->postprocess($self);

  #-----------------------------------------------------------------------------
  # Send result away except when NOOUT is requested. When NOOUT is used for
  # SendToSelect, the caller might want to use the result in some other way.
  #
  if( $self->sendToSelect ne 'NOOUT' )
  {
    # Get the input filename or data label to get the path to the file.
    # Get the basename from it.
    #
    my $ifile = $self->inputFile || $self->dataLabel;
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
    say $outputHandler $trobj->resultText;

    close $outputHandler;
  }
}

#-------------------------------------------------------------------------------

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
  my $yaml2xml = Data2xml->new( inputFile => $filename
                              , dataFileType => 'Yaml'
                              , logging => 1
                              , requestDocument => 0
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

  my $d2xml = Data2xml->new( inputData => $data
                           , dataLabel => 'internal'
                           , logging => 1
                           , requestDocument => 2
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
