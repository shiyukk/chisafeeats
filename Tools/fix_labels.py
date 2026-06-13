#!/usr/bin/env python3
"""Hand-authored, domain-correct translations for the high-visibility, MT-prone
labels (inspection results, statuses, risk). Overrides the machine output."""
import re

HAND = {
 "pl": {"result.pass":"Pozytywny","result.conditions":"Warunkowo","result.fail":"Negatywny",
        "result.closed":"Zamknięte","result.other":"Inne","result.noEntry":"Brak wstępu",
        "result.notReady":"Niegotowe","result.notLocated":"Nie znaleziono",
        "status.ok":"OK","status.caution":"Uwaga","status.problem":"Problem",
        "risk.high":"Wysokie ryzyko","risk.medium":"Średnie ryzyko","risk.low":"Niskie ryzyko",
        "legend.unchecked":"Niezbadane","history.fixed":"naprawione"},
 "ru": {"result.pass":"Пройдено","result.conditions":"Условно","result.fail":"Не пройдено",
        "result.closed":"Закрыто","result.other":"Другое","result.noEntry":"Нет доступа",
        "result.notReady":"Не готово","result.notLocated":"Не найдено",
        "status.ok":"OK","status.caution":"Внимание","status.problem":"Проблема",
        "risk.high":"Высокий риск","risk.medium":"Средний риск","risk.low":"Низкий риск",
        "legend.unchecked":"Не проверено","history.fixed":"исправлено"},
 "pt-BR": {"result.pass":"Aprovado","result.conditions":"Aprovado com condições","result.fail":"Reprovado",
        "result.closed":"Fechado","result.other":"Outro","result.noEntry":"Sem acesso",
        "result.notReady":"Não pronto","result.notLocated":"Não localizado",
        "status.ok":"OK","status.caution":"Atenção","status.problem":"Problema",
        "risk.high":"Risco alto","risk.medium":"Risco médio","risk.low":"Risco baixo",
        "legend.unchecked":"Não inspecionado","history.fixed":"corrigido"},
 "fr": {"result.pass":"Conforme","result.conditions":"Conforme sous conditions","result.fail":"Non conforme",
        "result.closed":"Fermé","result.other":"Autre","result.noEntry":"Accès refusé",
        "result.notReady":"Pas prêt","result.notLocated":"Introuvable",
        "status.ok":"OK","status.caution":"Attention","status.problem":"Problème",
        "risk.high":"Risque élevé","risk.medium":"Risque moyen","risk.low":"Risque faible",
        "legend.unchecked":"Non inspecté","history.fixed":"corrigé"},
 "uk": {"result.pass":"Пройдено","result.conditions":"Умовно","result.fail":"Не пройдено",
        "result.closed":"Закрито","result.other":"Інше","result.noEntry":"Немає доступу",
        "result.notReady":"Не готово","result.notLocated":"Не знайдено",
        "status.ok":"OK","status.caution":"Увага","status.problem":"Проблема",
        "risk.high":"Високий ризик","risk.medium":"Середній ризик","risk.low":"Низький ризик",
        "legend.unchecked":"Не перевірено","history.fixed":"виправлено"},
}

for folder, m in HAND.items():
    path = "Resources/%s.lproj/Localizable.strings" % folder
    lines = open(path, encoding="utf-8").read().splitlines()
    out = []
    for line in lines:
        mt = re.match(r'^"([^"]+)"\s*=', line)
        if mt and mt.group(1) in m:
            out.append('"%s" = "%s";' % (mt.group(1), m[mt.group(1)]))
        else:
            out.append(line)
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("fixed labels:", folder)
