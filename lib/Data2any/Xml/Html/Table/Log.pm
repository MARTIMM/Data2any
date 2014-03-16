package Data2xml::Html::Table::Log;
use Modern::Perl;
use Moose;
extends 'Data2xml::Tools';

#-------------------------------------------------------------------------------
use YAML ();
use Text::Tabs ();

use constant VERSION => '0.5';

#-------------------------------------------------------------------------------
has '+version' => ( default => VERSION);

has table =>
    ( is => 'rw'
    , default => sub{ return {}; }
    , isa => 'HashRef'
    , traits => ['Hash']
    , handles =>
      { addTable        => 'set'
      , clearTable      => 'clear'
      }
    );

has tag =>
    ( is => 'rw'
    , isa => 'ArrayRef[Str]'
    , default => sub{ return []; }
    , traits  => ['Array']
    , handles =>
      { setTagName      => 'unshift'
      , addTagAttribute => 'push'
      , getTag          => 'join'
      , clearTag        => 'clear'
      }
    );

################################################################################
#
sub help
{
  print <<EOHELP;

  Plugin to produce a log table. The table is build with one call
  to Table::log plugin as follows

  - !perl/Data2xml::Table::Log  Initialize and start the table
     caption                    The title text for the table
     id                         The id for the table. Can be used for css.
     class                      The class for the table. Can be used for css.
     data                       The log entries

  An example;
  - !perl/Data2xml::Table::Log
     class: log
     id: server
     caption: Log entries for server appDBServer
     data:
      - 2012 10 22: Clone van VM appDBServer
      - 2012 10 23: >
         Reboot van server systeem

EOHELP
}

################################################################################
# Proces in which phase we are.
#
sub process
{
  my($self) = @_;
return;
  my $tl = $self->userData;

  $self->clearTag;
  $self->setTagName('table');
  $self->add2Tag( 'class', $tl->{class});
  $self->add2Tag( 'id', $tl->{id});
  my $tableTagStr = $self->getTag(' ');

  my $tableData = [];
  push @$tableData, { caption => $tl->{caption}} if defined $tl->{caption};

  push @$tableData
     , { colgroup =>
         [ { "col width='80px'" => ''}
         , { "col" => ''}
         ]
       };

  my $hRecords = [];
  push @$hRecords
     , { tr =>
         [ { th => 'Date'}
         , { th => 'Log Message'}
         ]
       };
  push @$tableData, { thead => $hRecords};

  if( defined $tl->{data} )
  {
    $self->getFromData( $tableData, $tl->{data});
  }

  elsif( defined $tl->{logfile} )
  {
    $self->getFromFile($tableData);
  }

#  $self->addTable($tableTagStr => $tableData);
#  return $self->table;
  return ({$tableTagStr => $tableData});
}

################################################################################
# Proces in which phase we are.
#
sub getFromData
{
  my( $self, $tableData, $data) = @_;

  my $bRecords = [];
  foreach my $logEntry (@$data)
  {
    my( $date, $message);
    if( ref($logEntry) eq 'HASH' )
    {
      ( $date, $message) = each %$logEntry;
    }

    else
    {
      ( $date, $message) = ( '', $logEntry);
    }

    push @$bRecords
       , { tr =>
           [ { th => $date}
           , { td => $message}
           ]
         };
  }
  push @$tableData, { tbody => $bRecords};
}

################################################################################
# Get log entry data from yaml file and filter data in the process on
# key and time.
#
sub getFromFile
{
  my( $self, $tableData) = @_;
return;
  my $tl = $self->userData;

  my $cObject = $self->callerObject;
  my $uv = $self->userVariables;
  my $filter = $tl->{filter};
  $filter = $cObject->convertDollarVars1( $filter, $uv) if $filter =~ m/\$/;

  my $logfile = $tl->{logfile};
  if( -r $logfile )
  {
    local $/ = undef;

    open( YAML, "< $logfile");
    my $yamlText = <YAML>;
    close YAML;

    my @documents = YAML::Load(Text::Tabs::expand($yamlText));
    $self->{logfileData} = shift @documents;
    if( !defined $self->{logfileData} )
    {
      print STDERR "No documents found\n";
      push @$tableData, { tbody => []};
#      return @$tableData;
    }
  }

  else
  {
    print STDERR "Logfile $logfile not found or not readable\n";
#    return @$tableData;
  }

  if( defined $self->{logfileData}{$filter} )
  {
    my $data = $self->{logfileData}{$filter};
    $self->getFromData( $tableData, $data);
  }

  else
  {
    print STDERR "Key $filter not found in logfile\n";
    push @$tableData, { tbody => []};
  }

#  return @$tableData;
}

#-------------------------------------------------------------------------------
no Moose;
1;
