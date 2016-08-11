use strict;
use Test;

# Anzahl der Tests muss am Anfang angegeben werden
BEGIN { plan tests => 19 }

# Modul laden...
use BSP::PrettyPrinter qw(pretty_print);

# 1 - Identische Transformation
  ok(pretty_print("<head></head>")             , "<head></head>");
# 2 - HTML-Elementnamen immer lowercase
  ok(pretty_print("<HEAD></heAD>")             , "<head></head>");
# 3 - Scripting bleibt erhalten
  ok(pretty_print("<%--Test--%><head> </head>") , "<%--Test--%>\n<head></head>");
# 4 - HTML-Kommentare bleiben erhalten
  ok(pretty_print("<!--Test--!><head></head>") , "<!--Test--!>\n<head></head>");
# 5 - Umbrüche werden übernommen
  ok(pretty_print("<head>\n\n\n\n\n  </head>") , "<head>\n\n\n\n\n</head>");
# 6 - Spacing wird durch Pretty Print neugemacht
  ok(pretty_print("<head>      </head>")       , "<head></head>");
# 7 - BSP-Elemente sind gross-klein-sensitiv
  ok(pretty_print("<z:Title>Titel</z:Title>")  , "<z:Title>Titel</z:Title>");
# 8 - Attribute in Anführungszeichen
  ok(pretty_print("<td class=blueCell>")       , q(<td class="blueCell">));
# 9 - Boolesche Attribute HTML-konform
  ok(pretty_print("<td nowrap>")               , q(<td nowrap>));
#10 - HTML und BSP zusammenformatieren
  ok(pretty_print("<HEAD><z:Title>Titel</z:Title></HEAD>")
     , "<head>\n  <z:Title>Titel</z:Title></head>");
#11 - Formatierung mit Umbruch
  ok(pretty_print("<tr>\n<td>Zelle 1</td>\n     <td>Zelle 2</td>\n    </tr>"),
                  "<tr>\n  <td>Zelle 1</td>\n  <td>Zelle 2</td>\n</tr>");
#12 - Formatierung ohne Umbruch - trotzdem umbrechen!
  ok(pretty_print("<tr>\n<td>Zelle 1</td><td>Zelle 2</td>\n    </tr>"),
                  "<tr>\n  <td>Zelle 1</td>\n  <td>Zelle 2</td>\n</tr>");
#13 - BSP-Elemente ohne Inhalt zusammenziehen
  ok(pretty_print("<z:input> \n   </z:input>"),"<z:input/>");
#14 - CDATA-Tags überspringen
  ok(pretty_print("<script><hUgO></script>"),
                qq(<script type="text/javascript"><hUgO></script>));
                
#15 - Inline Tags in der Zeile fortsetzen
  ok(pretty_print("<table><tr><td>Peter <b>Pan</b></td></tr></table>"),
                  "<table>\n  <tr>\n    <td>Peter <b>Pan</b></td></tr></table>");                                 
#16 - Lange Attribute werden in Folgezeilen formatiert dargestellt
  ok(pretty_print('<input type="checkbox" disabled="true" class="disabled readonly inputElement firstRow" readonly onclick="doOnClick(this);" title="Bitte drücken" id="ersteCheckbox">')."\n",<<"EXPECTED");
<input class    = "disabled readonly inputElement firstRow"
       disabled = "true"
       id       = "ersteCheckbox"
       onclick  = "doOnClick(this);"
       readonly
       title    = "Bitte drücken"
       type     = "checkbox">
EXPECTED

#17 - OTR-Texte nicht umbrechen, wenn in Zeile
  ok(pretty_print("<div><%=otr(ZSRS_BSP/KUNDENNR)%></div>"),
     "<div><%=otr(ZSRS_BSP/KUNDENNR)%></div>");          

#18 - OTR-Texte eingerückt lassen, wenn sie vom User eingerückt wurden
  ok(pretty_print("<div>\n  <%=otr(ZSRS_BSP/KUNDENNR)%>\n</div>"),
     "<div>\n  <%=otr(ZSRS_BSP/KUNDENNR)%>\n</div>");          

#19 - Attribut Indentation, sobald der User selbst Umbrüche eingefügt hat
  ok(pretty_print(qq(<div class="headline"\n id="news">))."\n",<<"EXPECTED");
<div class = "headline"
     id    = "news">
EXPECTED

       