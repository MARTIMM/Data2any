package Data2xml::Html::Table::ServerInfo;
use Modern::Perl;
use Moose;
extends 'Data2xml::Tools';

#-------------------------------------------------------------------------------
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
  to Table::serverInfo plugin as follows

  - !perl/Data2xml::Table::ServerInfo
                                Initialize and start the table

    caption                     The title text for the table
    id                          The id for the table. Can be used for css.
    class                       The class for the table. Can be used for css.
    dataL                       The information on the left side of the table
    dataR                       The information on the right side of the table

  An example;

     - !perl/Data2xml::Table::serverInfo
        class: log
        id: server
        caption: Server info

        dataL:
         - Nbr cpu:
         - 2012 10 23:

        dataR:
         - Nbr cpu:
         - 2012 10 23:

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
         [ { "col width='15%'" => ''}
         , { "col width='35%'" => ''}
         , { "col width='15%'" => ''}
         , { "col width='35%'" => ''}
         ]
       };

  my $bRecords = [];

  my $dataL = $tl->{dataL};
  $dataL = [] unless defined $dataL;
  my $dataR = $tl->{dataR};
  $dataR = [] unless defined $dataR;
  my $dataLR = $tl->{dataLR};
  $dataLR = [] unless defined $dataLR;

  while( scalar(@$dataL) or scalar(@$dataR) )
  {
    my( $leftColumnHead, $leftColumnData, $rightColumnHead, $rightColumnData);

    my $dataLEntry = shift @$dataL;
    if( ref $dataLEntry eq 'HASH' )
    {
      ( $leftColumnHead, $leftColumnData) = each(%$dataLEntry);
    }

    else
    {
      ( $leftColumnHead, $leftColumnData) = ( '', '');
    }


    my $dataREntry = shift @$dataR;
    if( ref $dataREntry eq 'HASH' )
    {
      ( $rightColumnHead, $rightColumnData) = each(%$dataREntry);
    }

    else
    {
      ( $rightColumnHead, $rightColumnData) = ( '', '');
    }

    push @$bRecords
       , { tr =>
           [ { th => $leftColumnHead}
           , { td => $leftColumnData}
           , { th => $rightColumnHead}
           , { td => $rightColumnData}
           ]
         };
  }

  while( scalar(@$dataLR) )
  {
    my( $firstColumnHead, $next3ColumnsData);
    my $dataLREntry = shift @$dataLR;
    if( ref $dataLREntry eq 'HASH' )
    {
      ( $firstColumnHead, $next3ColumnsData) = each(%$dataLREntry);
    }

    push @$bRecords
       , { tr =>
           [ { th => $firstColumnHead}
           , { "td colspan=3" => $next3ColumnsData}
           ]
         };
  }

  push @$tableData, { tbody => $bRecords};

#  $self->addTable($tableTagStr => $tableData);
#  return $self->table;
  return ({$tableTagStr => $tableData});
}

#-------------------------------------------------------------------------------
no Moose;
1;
