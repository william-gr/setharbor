import 'dart:convert';

import 'plan.dart';

const webBase = 'https://william-gr.github.io/setharbor/open/';
const appBase = 'setharbor://workout';
const guideUrl = 'https://william-gr.github.io/setharbor/chatgpt/';
const maxLinkLength = 64000;
Json parseWorkoutLink(String address) {
  if (address.length > maxLinkLength) invalid('Link muito grande');
  if (!address.startsWith('$webBase#') && !address.startsWith('$appBase#')) {
    invalid('Destino do link inválido');
  }
  final fragment = address.contains('#')
      ? address.substring(address.indexOf('#') + 1)
      : '';
  if (!fragment.startsWith('v1.')) invalid('Versão do link inválida');
  final encoded = fragment.substring(3);
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(encoded)) {
    invalid('Conteúdo do link inválido');
  }
  final plan = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
  ) as Json;
  validatePlan(plan);
  return plan;
}

String encodeWorkoutLink(Json plan) {
  validatePlan(plan);
  final address =
      '$webBase#v1.${base64Url.encode(utf8.encode(jsonEncode(plan))).replaceAll('=', '')}';
  if (address.length > maxLinkLength) {
    invalid('Ficha muito grande para um link');
  }
  return address;
}

String chatPrompt(Json plan, bool includeCurrentPlan) {
  validatePlan(plan);
  final request =
      'Quero ${includeCurrentPlan ? 'revisar minha ficha' : 'criar uma ficha nova'} no SetHarbor. Leia as instruções e o catálogo em $guideUrl Pergunte meus objetivos, frequência e equipamentos antes de criar. Organize treinos cíclicos A/B/C, sem dias fixos. Entregue um link clicável Abrir no SetHarbor, sem copiar JSON nem importar arquivo. Se não conseguir consultar a página ou gerar o link corretamente, avise; não invente IDs ou codificação. Revisão atual: ${plan['revision']}.';
  if (!includeCurrentPlan) return request;
  final clean = <String, dynamic>{
    for (final key in ['format', 'schemaVersion', 'revision', 'title'])
      key: plan[key],
  };
  clean['days'] = daysOf(plan)
      .map(
        (day) => {
          for (final key in ['id', 'name', 'focus'])
            if (day.containsKey(key)) key: day[key],
          'exercises': (day['exercises'] as List)
              .map(
                (item) => {
                  for (final key in ['id', 'name', 'sets', 'reps', 'catalogId'])
                    if (item.containsKey(key)) key: item[key],
                },
              )
              .toList(),
        },
      )
      .toList();
  return '$request\n\nFicha atual:\n${jsonEncode(clean)}';
}
