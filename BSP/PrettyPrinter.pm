# ----------------------------------------------------------------------
# BSP Pretty Printer
# ----------------------------------------------------------------------
# Doku siehe http://bsp.mits.ch/supplements/pretty.htm
# (C) R�diger Plantiko, Migros IT-Services (MITS), 7/2007
# ----------------------------------------------------------------------

package BSP::PrettyPrinter;

use HTML::Parser 3; # HTML::Parser mindestens in Version 3
use strict;
use Exporter;

our $VERSION = 0.9;
our @ISA     = qw(Exporter);
our @EXPORT  = qw(&pretty_print);

# ----------------------------------------------------------------------
# Pretty Print - einzige �ffentliche Methode des Pakets
# Erwartet unformatierten String
# Gibt formatierten String zur�ck
# ----------------------------------------------------------------------
sub pretty_print($) {
  my @bspParts;
# BSP-Scripting vorl�ufig durch HTML-Kommentare ersetzen
  my $buf = substituteBsp(shift,\@bspParts);
# Transformation mithilfe des HTML::Parsers durchf�hren
  return transform( $buf, \@bspParts );
  }


sub substituteBsp( ) {

  my ($buf,$bspParts) = @_;

# ----------------------------------------------------------------------
# Erster Durchgang
# Ersetze alle BSP-Direktiven durch HTML-Kommentare <!--BSP1--> etc.
# Baue gleichzeitig einen Array mit den Originalausdr�cken auf
# ----------------------------------------------------------------------
  my $bspCounter = 0;
  my $buf1 = "";
  my $posi=0;
  my $pre;
  my $spc;
  my $bspTag;

# Regul�rer Ausdruck trifft alle Formen von Scripting
# <% ... %>, <%= ... %> und <%-- --%>
  while ( $buf =~ /(.*?)(\s*)(<%(.*?)%>)/gs) {
    ($pre,$spc,$bspTag) = ($1,$2,$3);
# Kontrolliert einen Zeilenumbruch einf�gen
# Einr�ckung des Benutzers stehen lassen
    if ($spc =~ /\n/ ) {
      (my $s1 = $spc) =~ s/^.*(\n[^\n]*)$/$1/s;
      $bspTag = $s1 . $bspTag;
      }
# Ersetzungsausdruck aufbauen, $bspCounter wird der Index
# im Array @$bspParts
    $buf1 .= $pre . "<!--_bsp$bspCounter-->" ;
    push( @$bspParts, $bspTag);
    $bspCounter++;
    $posi = pos($buf);
    }

# Den Schwanz (alles ab letztem gefundenen Scriptingausdruck)
# noch hintanstellen
  $buf1 .= substr( $buf, $posi);

  return $buf1;

  }

# ----------------------------------------------------------------------
# Zweiter Durchgang: HTML-Parser / Pretty Printer
# ----------------------------------------------------------------------

{

# Private Daten des HTML-Parsing-Blocks:

# Referenz auf den Stack der BSP-Ausdr�cke
my $bspParts;

# Parser-Stack
my @stack;
my $result; # Ergebnis (neu)

# Tags, die nicht unbedingt geschlossen werden m�ssen
my %nonClosingTags;
# Tags, die keinen Zeilenumbruch erfordern
my %inlineTags;
# Tags, die stets Text enthalten (kein HTML)
my %cdataTags;
# Flag, dass wir gerade in einem solchen Tag sind
my $cdataContent;
# Kritische L�nge, ab der die Attribute umgebrochen werden
my $attBreakLimit;
# Einr�cktiefe
my $indentDepth;

sub transform {

  (my $buf1,$bspParts,my $config) = @_;

  my $bspOpen = 0;

# Initialisierungen
  do_init($config);
  init_result();

# Parser instanziieren, Handler definiern, parse() aufrufen
  my $parser = HTML::Parser->new(
    default_h => [ \&others,          'event,text' ],
    start_h   => [ \&start_handler,   'self,tagname,attr,text' ],
    end_h     => [ \&end_handler,     'self,tagname,text' ],
    text_h    => [ \&text_handler,    'self,text' ],
    comment_h => [ \&comment_handler, 'self,text' ]
    ) || die $!;
# Case Sensitive ist n�tig wegen der BSP-Elemente
  $parser->case_sensitive( 1 );
# XML-Mode ist n�tig wegen der BSP-Elemente
# Hilft, dass selbstschliessende Tags korrekt erkannt werden
  $parser->xml_mode( 1 );
  $parser->boolean_attribute_value( "_BOOL_" );
# Nun das Parsing durchf�hren...
  $parser->parse($buf1) || die $!;
# ... und beenden
  $parser->eof;

# Ausgabestring zur�ckgeben
  my $buf2 = getResult();
  $buf2 =~ s/^\n// unless $buf1 =~ /^\n/;
  return $buf2;

  }

# ----------------------------------------------------------------------
# Initialisierungen f�r das Parsing - Konfigurationseinstellungen
# ----------------------------------------------------------------------
sub do_init {
  my $config = shift;
  my $return;

# Selbstausf�hrendes Konfigurationsfile ...
  if ($config) {
    unless ($return = do $config) {
      die "couldn't parse $config: $@"         if $@;
      die "couldn't do $config: $!"            unless defined $return;
      die "couldn't run $config"               unless $return;
      }
    }
  else {
# ... oder Konfigurationen aus diesem Script (siehe unten)
    $return = standard_config();
    }

# Tag-Mengen als Hashs aufbereiten
  %inlineTags     = map { ($_,1) } @{$return->{inlineTags}};
  %nonClosingTags = map { ($_,1) } @{$return->{nonClosingTags}};
  %cdataTags      = map { ($_,1) } @{$return->{cdataTags}};

# Zeilenzahl, ab der es einen Umbruch beim Attribut-Rendern gibt
  $attBreakLimit  = $return->{attBreakLimit};

# Einr�cktiefe
  $indentDepth    = $return->{indentDepth};

  }

# ----------------------------------------------------------------------
# Ereignisbehandler f�r HTML::Parser
# ----------------------------------------------------------------------
# �ffnende Tags
sub start_handler {
  
  my ($self,$tagname,$attr,$text) = @_;
  my (%myAttributes,$key,$value,$prefix);
  my $atts="";
  
  my $deepPrint = (length( $text ) > $attBreakLimit or $text =~ /\n/);

# Tags innerhalb von CDATA als Text behandeln
  if ($cdataContent) {
    purePrint( $text );
    push @stack, [ "text", $text ];
    return;
    }

# HTML-Tags ( = die ohne Namespace) kleinschreiben
  $tagname = lc $tagname unless $tagname =~ /:/;

# Merken, dass ein CDATA-Tag ge�ffnet wurde
  if (exists $cdataTags{$tagname}) {
    $cdataContent = 1;
    }

# Zeilenumbruch f�r Nicht-Inline-Tags
  newLine() unless $inlineTags{lc $tagname};

# MIME-Type f�r JavaScript setzen
  if ($tagname =~ /script/i ) {
# Die einzige Scriptsprache, die wir haben
    $attr->{"type"} = "text/javascript";
    }

# HTML-Attributnamen kleinschreiben
  foreach $key (sort keys %$attr) {
    $value = $attr->{$key};
    $value =~ s/<!--_bsp(\d+)-->/{@$bspParts[$1]}/ges;
    $key = lc $key unless $tagname =~ /:/;
# <script> wird mit type spezifiziert, nicht mit language
    next if $tagname eq "script" and $key eq "language";
    if ($deepPrint) {
# Lange Elemente: Werte zun�chst in Hash aufnehmen
      $myAttributes{$key} = $value;
      }
    else {
# Werte anf�gen
      if ($value eq "_BOOL_") {
        $atts .= qq( $key);
        }
      else {
        $atts .= qq( $key="$value");
        }
      }
    }

# Elementdaten merken
  push @stack, [ "start", $tagname, $text, $atts, \%myAttributes, outLength() ];

# Inline-Tag? Dann schliessenden Whitespace des letzten Text-Elements ausgeben
  purePrint(getTerminatingWhiteSpace(-1)) if $inlineTags{$tagname};

# Formatierte Ausgabe, falls kritische L�nge �berschritten oder der User einen Umbruch eingef�gt hat
  if ($deepPrint) {
    deepPrintWithAttributes( $tagname, \%myAttributes );
    }
  else {
    deepPrint("<$tagname$atts>", $inlineTags{$tagname});
    }

# Attribute, die nicht geschlossen werden m�ssen, �ndern nicht die Einr�cktiefe
  if (not exists $nonClosingTags{$tagname} ) {
    incDepth();
    }
  }

# Behandelt Text und BSP-Scripting
sub text_handler {
  my ($self,$text) = @_;

# Text und aktuellen Offset merken
  push @stack, [ "text", $text, outLength() ];

# Text, der nur aus Leerraum besteht, ignorieren
  return if $text =~ /^\s*$/ && not $cdataContent;

# Schliessenden Leerraum entfernen
  $text =~ s/(\S)\s*$/$1/s unless $cdataContent;

# Ausgabe
  purePrint($text);

  }

# Endebehandlung
sub end_handler {

  my ($self,$tagname,$text) = @_;
  my $emptyContent = 0;
  my @start;

  $tagname = lc $tagname unless $tagname =~ /:/;

# Flag zur�cksetzen, wenn ein CDATA-Element beendet wird
  $cdataContent = 0 if $cdataTags{$tagname};

# Innerhalb von CDATA-Inhalt: Text ausgeben, merken, fertig
  if ($cdataContent) {
    push @stack, ["text",$text, outLength()];
    purePrint($text);
    return;
    }

# Ermitteln, wieviele Newlines am Schluss des Inhalts stehen
  my $terminatingNewLines = getTerminatingNewLines();

# Ein BSP-Element schliesst sich selbst
  if ($tagname =~/:/ and emptyContent()) {
    if ( (@start = @{lastStart()}) &&
         $tagname eq $start[1] ) {
      decDepth();
# Ausgabe zur�ckspulen
      setOutLength($start[-1]);
      if ($start[3]) {
        deepPrint("<$start[1]$start[3]/>");
        }
      else {
        deepPrintWithAttributes( $start[1], $start[4], 1 );
        }
      return;
      }
    }

# Information auf Stack legen
  push @stack, ["end",$tagname, outLength()];

# Einr�cktiefe
  decDepth() unless $nonClosingTags{$tagname};

# Schliessende Zeilenwechsel gem�ss Elementinhalt
  newLine($terminatingNewLines) unless $inlineTags{$tagname};

  if ($terminatingNewLines) {
    deepPrint("</$tagname>");
    }
  else {
    purePrint("</$tagname>");
    }
  }

# Kommentarbehandler
sub comment_handler {
  my $buf = $_[1];
  if ($buf =~ s/<!--_bsp(\d+)-->/{@$bspParts[$1]}/ges ) {
    push @stack, ["scripting",$buf,outLength()];
    }
  else {
    push @stack, ["comment",$buf, outLength() ];
    }

# Schliessende Zeilenumbr�che des vorangehenden Textes reproduzieren
  $_=getTerminatingNewLines(-1);
  newLine(getTerminatingNewLines(-1));

  purePrint($buf);
  }

sub others {
# Alle nicht speziell behandelten Events: Merken, ausgeben
  my ($event, $text) = @_;
  push @stack, [$event,$text,outLength()];
  purePrint($text);
  }


# ----------------------------------------------------------------------
# Routinen f�r den Zugriff auf den Elementstack
# ----------------------------------------------------------------------

sub getTerminatingNewLines {
  my $off = shift || 0;
  return 0 if $off < -$#stack;
  my $newlines = getTerminatingWhiteSpace($off);
  $newlines =~ s/[^\n]//gs;
  return length($newlines);
  }

sub getTerminatingWhiteSpace {
  my $off = shift || 0;
  return 0 if $off < -$#stack;
# Stack auswerten: Wieviele Zeilenumbr�che
# enthielt das Element am Ende?
  my @tos = @{$stack[-1+$off]};
  return "" unless $tos[0] eq "text";
  $tos[1] =~ m/\S?(\s*)$/s ;
  return $1;
  }

sub emptyContent {
# Stack auswerten: Ist dieses Element leer?
  my @tos;
  for (reverse @stack) {
    @tos = @$_;
# Kommentare ignorieren
    next if $tos[0] eq "comment";
# Scripting im Elementinhalt: Also nicht inhaltleer
    return 0 if $tos[0] eq "scripting";
# Funktion wird vor dem Output von end in den Stack gerufen
# Trifft er auf ein Ende-Tag, ist klar, dass das Element einen
# Inhalt haben muss
    return 0 if $tos[0] eq "end";
    if ($tos[0] eq "text") {
# Nichtleere Texte sind ebenfalls ein Inhalt
      return 0 unless $tos[1] =~ /^\s*$/g;
      }
    elsif ($tos[0] eq "start") {
# Wenn wir hier vorbeikommen, enthielt das Element nur \s*
      return 1;
      }
    }
# Kein ausgewogener Element-Stack
  return 0;
  }

sub lastStart {
# Letztes Start-Element auf dem Stack ermitteln
  my @tos;
  for (reverse @stack) {
    @tos = @$_;
    return \@tos if $tos[0] eq "start";
    }
  return undef;
  }

sub lastElementType {
# Letzten Element-Typ zur�ckgeben
  my $off = shift || 0;
  return 0 if $off < -$#stack;
  my @tos = @{$stack[-1+$off]};
  return $tos[0];
  }

# ----------------------------------------------------------------------
# Einger�ckter Druck
# ----------------------------------------------------------------------
{
# statische "private" Variable, Zugriff nur durch folgenden Subs
# Workarea (Kopfzeile) des Stacks
  my $wa = "";
# $depth bedeutet die aktuelle Einr�cktiefe
  my $depth = 0;
  sub init_result {
    $wa = "";
    $depth = 0;
    }
# Zeile mit Einr�ckung ausgeben
  sub deepPrint {
    my ($text,$pure) = @_;
    if ($pure) {
      purePrint( $text );
      }
    else {
      purePrint( " " x $depth . $text );
      }
    }
  sub purePrint {
    $wa .= shift;
    }
  sub newLine {
    my $times = @_ ? shift : 1;
    $wa .= "\n" x $times;
    }
  sub getResult {
    my $result = $wa;
    return $result;
    }
  sub outLength() {
    return length($wa);
    }
  sub setOutLength() {
    $wa = substr( $wa, 0, shift);
    }
# �ffnendes Element mit Attribut-Alignment ausgeben
  sub deepPrintWithAttributes {
    my ($tagname, $atts, $closing) = @_;
    my $pre = " " x $depth;
    my $firstTime = 1;
    my $line = "$pre<$tagname";
    my $key;
    my $maxKeyLength = 0;
    my $value;
    purePrint( $line );
    $pre = "\n" . ( " " x (length( $line ) + 1) );
    foreach $key (keys %$atts) {
      if (length( $key ) > $maxKeyLength) {
        $maxKeyLength = length( $key );
        }
      }
    foreach $key (sort keys %$atts) {
      if ($firstTime) {
        $firstTime = 0;
        purePrint(" ");
        }
      else {
        purePrint( $pre );
        }
      $value = $atts->{$key};
      if ($value eq "_BOOL_") {
        purePrint( $key );
        }
      else {
        purePrint( $key .
              (" " x ($maxKeyLength - length($key))) .
              qq( = "$value") );
        }
      }
    purePrint($closing ?  "/>" : ">" );
    }

# Einr�cktiefe erh�hen
  sub incDepth {
    $depth += $indentDepth;
    }
# Einr�cktiefe erniedrigen, wenn m�glich
  sub decDepth {
    $depth -= $indentDepth;
    if ($depth < 0) {
      $depth = 0;
      }
    }
  }  # Ende Print-Block

}  # Ende Parser-Block


# ----------------------------------------------------------------------
# Standard-Konfigurationen des BSP Pretty Printers
# ----------------------------------------------------------------------
sub standard_config {

my %conf;

# Tags, die nicht notwendig geschlossen werden m�ssen
  $conf{nonClosingTags}  =  ["input", "br", "p",
                             "textarea","area","hr",
                             "li","meta", "col",
                             "option","link","img"];
# Tags, die keinen Zeilenumbruch erfordern
  $conf{inlineTags}      =  ["b", "i", "tt","span"];
# Tags, deren Inhalt nicht geparsed, sondern als Text behandelt werden soll
  $conf{cdataTags}       =  ["script", "style"];
# Ab dieser L�nge: Attribute aufspalten
  $conf{attBreakLimit}   = 80;
# Einr�cktiefe f�r Schachtelungen
  $conf{indentDepth}     = 2;

\%conf;
}

1;
