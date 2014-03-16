# Translator to convert data to xml structures. Any plugins for this translator
# can be found at Data2any::Xml::*. Data2any will instanciate the translator by
# means of AppState::PluginManager.
#
package Data2any::Xml;

use version; our $VERSION = '' . version->parse("v0.1.0");
use 5.016003;
#-------------------------------------------------------------------------------

use Modern::Perl;
use Moose;

extends 'Data2any::TranslatorTools';

require HTTP::Headers;

#-------------------------------------------------------------------------------
#
has '+version' =>       ( default => $VERSION);

has substituteDollarVars =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , traits            => ['Bool']
    , handles           =>
      { setSubstituteDollarVars         => 'set'
      , stopSubstituteDollarVars        => 'unset'
      }
    );

has parseShortCutTags =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , traits            => ['Bool']
    , handles           =>
      { setParseShortCutTags            => 'set'
      , stopParseShortCutTags           => 'unset'
      }
    );

has convertCharacters =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , traits            => ['Bool']
    , handles           =>
      { setConvertCharacters            => 'set'
      , stopConvertCharacters           => 'unset'
      }
    );

has htmlCharCodes =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        my $mc = "([\\" . join( "\\", $self->getMatchChars) . "])";
        $self->setHtmlCharCodesRX(qr/$mc/);
      }

    , traits            => ['Hash']
    , handles           =>
      { getHtmlChar     => 'get'
      , hasHtmlChar     => 'defined'
      , getMatchChars   => 'keys'
      , addHtmlChar     => 'set'
      }
    );

has htmlCharCodesRX =>
    ( is                => 'ro'
    , writer            => 'setHtmlCharCodesRX'
    );

has resultText =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => ''
    , traits            => ['String']
    , handles           =>
      { addToXml        => 'append'
      , addBeforeXml    => 'prepend'
      , resetXml        => 'clear'
      , modifyXml       => 'substr'
      , replaceXml      => 'replace'
      , lengthXml       => 'length'
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    # Error codes
    #
    $self->code_reset;
#    $self->const( 'C_PROJECTREADERR',   qw(M_ERROR M_FAIL));
#    $self->const( 'C_TESTFILENTFND',    qw(M_WARNING));

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub init
{
  my( $self, $data2any) = @_;

  $self->addHtmlChar( '"' => 'quot', '&' => 'amp', '<' => 'lt', '>' => 'gt');
  $self->resetXml;
}

#-------------------------------------------------------------------------------
#
sub preprocess
{
  my( $self, $data2any, $root) = @_;

  # Get variables from the DocumentControl section
  #
  if( defined $data2any->getProperty('SetVariables') )
  {
    my $dvs = $data2any->getProperty('SetVariables');
    $data2any->setDollarVar(%$dvs) if ref $dvs eq 'HASH';
  }
}

#-------------------------------------------------------------------------------
#
sub goingUpHandler
{
  my( $self, $data2any, $node) = @_;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top nodes.
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
    if( $node->name eq 'CDATA' )
    {
      $self->addToXml("<![CDATA[");
      $self->stopConvertCharacters;
    }

    elsif( $node->name eq 'COMMENT' )
    {
      $self->addToXml("<!--");
      $self->stopConvertCharacters;
    }

    else
    {
      # Substitute dollar variable if nessesary
      #
      $node->rename($self->doSubstituteDollarVars($node->name))
        if $node->name =~ m/\$/;

      $self->addToXml($self->mkXmlStartTag($node));
    }
  }
}

#-------------------------------------------------------------------------------
#
sub goingDownHandler
{
  my( $self, $data2any, $node) = @_;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top nodes.
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
    if( $node->name eq 'CDATA' )
    {
#      my $chopChars = $node->get_attribute('chopChars');
#      $self->modifyXml( -$chopChars, $chopChars)
#        if defined $chopChars and $chopChars =~ m/^\d+$/;

      my $chopSpace = $node->get_attribute('chopTrailingSpace');
      $self->replaceXml( qr/[\s\n\r]+$/s, ' ')
        if defined $chopSpace and $chopSpace;

      $self->addToXml("]]>");
      $self->setConvertCharacters;
    }

    elsif( $node->name eq 'COMMENT' )
    {
      $self->addToXml("-->");
      $self->setConvertCharacters;
    }

    else
    {
      # Node converted when going up!
      # $node->rename($self->doSubstituteDollarVars($node->name))
      #  if $node->name =~ m/\$/;
      $self->addToXml('</' . $node->name . '>') if defined $node->name;
    }
  }
}

#-------------------------------------------------------------------------------
#
sub atTheEndHandler
{
  my( $self, $data2any, $node) = @_;

  if( ref($node) =~ m/AppState::NodeTree::Node(DOM|Root)/ )
  {
    # Skip the top root.
  }

  elsif( ref($node) eq 'AppState::NodeTree::NodeText' )
  {
    my $v = $self->convertValue($node->value);

    # Translate short written xml like b[...] or br[] into <b>...</b> or <br/>
    #
    $v = join( ''
             , @{$self->parser->textInit
                        ( $v
                        , 1
                        , sub {$self->rewriteShortcut(@_);}
                        )
                }
             ) if $self->parseShortCutTags;

#    $v =~ s/^\n+//;
#    $v =~ s/\n+$//;

    $self->addToXml($v);
  }

  elsif( ref($node) eq 'AppState::NodeTree::Node' )
  {
    if( $node->name eq 'InsertTag' )
    {

    }

    elsif( $node->name eq 'SetVariables' )
    {
      $data2any->setDollarVar( %{$node->attributes})
        if ref $node->attributes eq 'HASH';
    }

    elsif( $node->name eq 'Shortcuts' )
    {
      if( $node->get_attribute('parse') =~ m/(1|on|yes)/i )
      {
        $self->setParseShortCutTags;
      }

      elsif( $node->get_attribute('parse') =~ m/(0|off|no)/i )
      {
        $self->stopParseShortCutTags;
      }
    }

    elsif( $node->name eq 'DollarVars' )
    {
      if( $node->get_attribute('substitute') =~ m/(1|on|yes)/i )
      {
        $self->setSubstituteDollarVars;
      }

      elsif( $node->get_attribute('substitute') =~ m/(0|off|no)/i )
      {
        $self->stopSubstituteDollarVars;
      }
    }

    elsif( $node->name eq 'XML' )
    {
  # Test level, location and repeat
      my $version = $node->get_attribute('version');
      my $encoding = $node->get_attribute('encoding');
      my $standalone = $node->get_attribute('standalone');
      $self->addToXml("<?xml");
      $self->addToXml(" version=\"$version\"") if defined $version;
      $self->addToXml(" encoding=\"$encoding\"") if defined $encoding;
      $self->addToXml(" standalone=\"$standalone\"") if defined $standalone;
      $self->addToXml("?>\n");
    }

    elsif( $node->name eq 'DOCTYPE' )
    {
  # Test level, location and repeat
      my $root = $node->get_attribute('root');
      my $type = $node->get_attribute('type');
      my $id = $node->get_attribute('id');
      my $dtd = $node->get_attribute('dtd');
      $self->addToXml("<!DOCTYPE");
      $self->addToXml(" $root") if defined $root;
      $self->addToXml(" $type") if defined $type;
      $self->addToXml(" \"$id\"") if defined $id;
      $self->addToXml(" \"$dtd\"") if defined $dtd;

      # Check if there are entity definitions
      #
      my $entities = $node->get_attribute('entities');
      if( defined $entities and ref $entities eq 'ARRAY' )
      {
        $self->addToXml("[\n");
        foreach my $e (@$entities)
        {
          $self->addToXml("<!ENTITY $e>\n");
        }

        $self->addToXml("]");
      }

      $self->addToXml(">\n");
    }

    elsif( $node->name eq 'PI' )
    {
      my $target = $node->get_attribute('target');
      my $data = $node->get_attribute('data');
      $self->addToXml("<?$target");
      foreach my $dataItem (keys %$data)
      {
        $self->addToXml(" $dataItem='$data->{$dataItem}'");
      }

      $self->addToXml(" ?>");
    }

#    elsif( $node->name eq 'CDATA' )
#    {
#      my $cdata = $node->value;
#      $cdata =~ s/\n$//;
#      $self->addToXml("<![CDATA[$cdata]]>");
#    }

#    elsif( $node->name eq 'COMMENT' )
#    {
#      my $comment = $node->value;
#      $self->addToXml("<!--" . $comment . "-->\n");
#    }

    else
    {
      # Substitute dollar variable if nessesary
      #
      $node->rename($self->doSubstituteDollarVars($node->name))
        if $node->name =~ m/\$/;

      $self->addToXml($self->mkXmlStartEndTag($node));
    }
  }
}

#-------------------------------------------------------------------------------
#
sub mkXmlStartTag
{
  my( $self, $node) = @_;
  my $tag = '';
  if( $node->name )
  {
    $tag .= "<" . $node->name;
    my @attributes = $node->get_attributes;
    $tag .= $self->mkStringAttribute( $_->name, $_->value) for (@attributes);
    $tag .= ">";
  }

  return $tag;
}

#-------------------------------------------------------------------------------
#
sub mkXmlStartEndTag
{
  my( $self, $node) = @_;
  my $tag = '';
  if( $node->name )
  {
    $tag .= "<" . $node->name;
    my @attributes = $node->get_attributes;
    $tag .= $self->mkStringAttribute( $_->name, $_->value) for (@attributes);
    $tag .= " />";
  }

  return $tag;
}

#-------------------------------------------------------------------------------
# Called from parser parsing shortcut strings. When a shortcut string is
# like id[text words], $id holds the id before the brackets and $text comes from
# whithin the brackets. $text is an array reference. Return an array of text
# words as a result.
#
# Translate;
#  id[]         ("<id />")
#  id[text]     ("<id>", @$text, "</id>")
#
sub rewriteShortcut
{
  my( $self, $id, $text) = @_;

  return (defined $text and ref $text eq 'ARRAY')
         ? ("<$id>", @$text, "</$id>")
         : ("<$id />")
         ;
}

#-------------------------------------------------------------------------------
#
sub mkStringAttribute
{
  my( $self, $attrName, $attrValue) = @_;

#  my $str = " $attrName=" . '"' .  XML::Quote::xml_quote($attrValue) . '"';
  $attrName = $self->doSubstituteDollarVars($attrName) if $attrName =~ m/\$/;
  $attrValue = $self->doSubstituteDollarVars($attrValue) if $attrValue =~ m/\$/;
  $attrValue =~ s/["]/\&quot;/g;
  my $str = " $attrName=\"$attrValue\"";

if(0)
{
  if( $attrValue =~ m/^'[^']+'$/ )
  {
    $str .= $attrValue;
  }

  elsif( $attrValue =~ m/^"[^"]+"$/ )
  {
    $str .= $attrValue;
  }

  else
  {
    $str .= qq@"$attrValue"@;
  }
}

  return $str;
}

#-------------------------------------------------------------------------------
#
sub convertValue
{
  my( $self, $value) = @_;

  if( $self->convertCharacters )
  {
    my $mc = $self->htmlCharCodesRX;

    # Protect first any user written symbol entities
    #
    $value =~ s/\&(\w+);/__|$1|__/g;

    # Convert any characters
    #
    $value =~ s/($mc)/$self->convertHtmlChar($1)/eg if $value =~ m/$mc/;

    # Convert the protected entities back
    #
    $value =~ s/__\|(\w+)\|__/\&$1;/g;

#  $value = XML::Quote::xml_quote($value);
  }

  return $value =~ m/\$/ ? $self->doSubstituteDollarVars($value) : $value;
}


#-------------------------------------------------------------------------------
#
sub doSubstituteDollarVars
{
  my( $self, $value) = @_;

  # Fill in any variables if there are any and if substituting is turned on
  #
  if( $self->substituteDollarVars )
  {
    my( $counterName, $counterValue);
    do
    {
#      $counterName = undef;
      if( ( $counterName, $counterValue) =
          $value =~ m/\$(COUNT[_\w\d]+)=(\w+)/
        )
      {
        $self->setDollarVar( $counterName => $counterValue);
        $value =~ s/\$(COUNT[_\w\d]+)=(\w+)\s+//;
      }

      elsif( ($counterName) = $value =~ m/\$(COUNT[_\w\d]+)\+\+/ )
      {
        $counterValue =$self->getDollarVar($counterName);
        $value =~ s/\$(COUNT[_\w\d]+)\+\+/$counterValue/;
        $counterValue++;
        $self->setDollarVar( $counterName => $counterValue);
      }

      elsif( ($counterName) = $value =~ m/\$(COUNT[_\w\d]+)\-\-/ )
      {
        $counterValue =$self->getDollarVar($counterName);
        $value =~ s/\$(COUNT[_\w\d]+)\-\-/$counterValue/;
        $counterValue--;
        $self->setDollarVar( $counterName => $counterValue);
      }

    } while( defined $counterName );



    foreach my $vn ($self->getDVarNames)
    {
      last unless $value =~ m/\$\{?[_\w\d]+/;
      $value =~ s/\$\{?$vn\b\}?/$self->getDollarVar($vn)/ge;
    }
  }

  return $value;
}

#-------------------------------------------------------------------------------
# Convert a special character into html characters. E.g. & into &amp; etc.
# Other special characters where no keyboard representation is found must be
# typed directly like &euro;, &dagger; and &beta;.
#
sub convertHtmlChar
{
  my( $self, $char) = @_;

  return $char unless defined $char;

  my $str;
  if( $self->hasHtmlChar($char) )
  {
    $str = '&' . $self->getHtmlChar($char) . ';';
  }

  else
  {
    $str = $char;
  }

  return $str;
}


#-------------------------------------------------------------------------------
#
sub postprocess
{
  my( $self, $data2any) = @_;

  my $xmlHeader = '';

  #-----------------------------------------------------------------------------
  # Place a http header on top
  #
  my $httpHeader = $data2any->getProperty('HttpHeader');
  if( defined $httpHeader and ref $httpHeader eq 'HASH' )
  {
    my $h = HTTP::Headers->new;
    $h->header(%$httpHeader);
    $xmlHeader .= $h->as_string . "\n";
  }

  #-----------------------------------------------------------------------------
  # Add the xmlresult to the lines above and store it again.
  #
  $self->addBeforeXml($xmlHeader);
}

#-------------------------------------------------------------------------------

1;
#-------------------------------------------------------------------------------


__END__

#---
if(0)
{
  #-----------------------------------------------------------------------------
  # Work through all properties and store them into a hash. This means all
  # properties should be unique.
  #
  my( $tl_counter, $startIdx, $endIdx);
  my $tl_kwrds_rx = $self->tl_kwrds_rx;
  $tl_counter = 0;
  foreach my $propertySet (@$root)
  {
    my( @ktext, @vtext, $kt, $vt);

    foreach my $k (keys %$propertySet)
    {
      next unless $k =~ m/$tl_kwrds_rx/;

      # Test for keyword which will be all uppercase
      #
      if( $k =~ m/^[A-Z]+$/ )
      {
        $kt = $k;
        $vt = defined $propertySet->{$k} ? $propertySet->{$k} : '';
      }

      else
      {
        push @ktext, $k;
        $vt = $propertySet->{$k}
           if defined $propertySet->{$k} and $propertySet->{$k};
      }

      # Find the start and end of the document to process later
      #
      if( $k eq 'STARTDOCUMENT' )
      {
        $startIdx = $tl_counter + 1;
      }

      elsif( $k eq 'ENDDOCUMENT' )
      {
        $endIdx = $tl_counter - 1;
      }
    }

    $tl_counter++;

    if( defined $kt and defined $vt )
    {
      $self->setProperty( $kt => $vt);
    }

    else
    {
      $self->setProperty( join( ' ', @ktext) => $vt);
    }
  }

  # Set the start and end index if the keywords for it where not found
  #
  $startIdx //= 0;
  $endIdx //= $tl_counter - 1;

  # Take the slice and store in the docroot.
  #
#  $self->setDocRoot([@$root[$startIdx .. $endIdx]]);
}
#---
