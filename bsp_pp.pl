# ----------------------------------------------------------------------
# BSP Pretty Printer
# ----------------------------------------------------------------------
# Doku siehe http://bsp.mits.ch/supplements/pretty.htm
# (C) Rüdiger Plantiko, Migros IT-Services (MITS), 7/2007
# ----------------------------------------------------------------------

use lib "/data_mgb/D12/scripts";
use BSP::PrettyPrinter qw(pretty_print);
use strict;

# Eingabefile als erster Kommandozeilenparameter
# Optional Name des Konfigurationsscripts als zweiter Parameter
my ($file,$config) = @ARGV;
my $result;

if ($file) {
# Default-Endung ist .unf
  $file .= ".unf" unless $file =~ /\./ ;
  }
else {
  die <<"MINIDOC";
Verwendung:

   perl bsp_pp.pl VIEW [CONFIG]

VIEW              = Name der Datei, die den unformatierten Code enthält
CONFIG (optional) = Script für Konfigurationen

Wenn VIEW die File Extension .unf (unformatiert) oder
keine Extension hat, wird die formatierte Ausgabe in eine
gleichnamige Datei mit der Extension .for (formatiert)
geschrieben.

In allen anderen Fällen wird die Ausgabe in STDOUT geschrieben
MINIDOC
  }

$result = pretty_print( getInput( $file ) );

# Ausgabe von (.+).unf ("unformatiert") in $1.for ("formatiert"):
if ( $file =~ s/\.unf$/.for/i ) {
  open( OUTFILE, ">$file" ) or die qq(Kann "$file" nicht zum Schreiben öffnen);
  print OUTFILE $result;
  }
else {
# Dateiname war nicht /.+\.unf$/ ? Dann in stdout schreiben
  print $result;
  }

sub getInput {

# ----------------------------------------------------------------------
# Wir wenden die SLURP-Technik an - alles in einen String saugen -
# weil wir gewisse Vorarbeiten vor dem eigentlichen Parsingprozess
# machen müssen
# ----------------------------------------------------------------------
  my $file = shift;
  my $buf  = "";
  open( INFILE, $file ) or die "Kann $file nicht zum Lesen öffnen";
  while ( <INFILE> ) { $buf .= $_; } # sluuuuuurp
  return $buf;
  }
