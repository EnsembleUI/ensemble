// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

abstract class AriaLabelService {
  static void applyLabels(Map<String, String> explicitLabels) {
    if (!kIsWeb) return;
    final scriptContent = _buildScript(explicitLabels);
    (js.context['document'] as dynamic).head.append(
        js.context['document'].createElement('script')..text = scriptContent);
  }
}

String _buildScript(Map<String, String> explicitLabels) {
  final entries = explicitLabels.entries
      .map((e) => "['${_escape(e.key)}','${_escape(e.value)}']")
      .join(',');

  return "(function(){\n"
      "var map=new Map([${entries}]);\n"
      "function deriveName(text){if(!text)return '';var i=text.indexOf(' Tab ');if(i>0)return text.substring(0,i).trim();return (text.split('\\n')[0]||'').trim();}\n"
      "function run(){var nodes=document.querySelectorAll('flt-semantics');nodes.forEach(function(el){var span=el.querySelector('span');var text=(span&&span.textContent)||el.textContent||'';var label=null;map.forEach(function(v,k){if(text.toLowerCase().indexOf(k.toLowerCase())>-1){label=v;}});if(!label){label=deriveName(text);}if(label){el.setAttribute('aria-label',label);var c=el.closest('flt-semantics-container');if(c){c.setAttribute('aria-label',label);}}});}\n"
      "setTimeout(run,50);setTimeout(run,250);setTimeout(run,1000);\n"
      "var mo=new MutationObserver(function(){setTimeout(run,50);});mo.observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['style','class']});\n"
      "})();";
}

String _escape(String s) => s.replaceAll("'", "\\'");
