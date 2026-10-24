#!/usr/bin/env python3
"""question.md 의 ## Record 표를 읽어 회차 README 와 최상위 README 의 진행 표를 채운다.

결과를 적는 곳은 각 문제의 question.md ## Record 표 한 곳뿐이다. README 의 실제·결과·점수·실점
칸은 손으로 적지 말고 이 스크립트로 채운다. 회고, 자신감, 약점 메모, 반복 오답 목록은 손으로 적는
칸이라 건드리지 않는다.

    python3 scripts/update_progress.py
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SETS = 'abcdef'
DOMAINS = [
    'Cluster Setup',
    'Cluster Hardening',
    'System Hardening',
    'Minimize Microservice Vulnerabilities',
    'Supply Chain Security',
    'Monitoring, Logging and Runtime Security',
]
PASS = 67


def cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def row(cs):
    return '| ' + ' | '.join(cs) + ' |'


def read_question(path):
    t = open(path, encoding='utf-8').read()
    meta = dict(re.findall(r'^\| (\w[\w ]*?) \| (.*?) \|$', t.split('## Setup')[0], re.M))
    points = int(meta['Points'])
    domain = re.sub(r'\s*\(\d+%\)$', '', meta['Domain'])
    attempts = []
    if '## Record' in t:
        sec = t.split('## Record', 1)[1].split('\n---', 1)[0]
        for line in sec.splitlines():
            if not line.startswith('|') or line.startswith('|---') or line.startswith('| Date'):
                continue
            date, minutes, score, note = (cells(line) + [''] * 4)[:4]
            if score == '':
                continue
            attempts.append({'date': date, 'min': minutes, 'score': float(score)})
    return {'points': points, 'domain': domain, 'attempts': attempts}


def fmt(n):
    return str(int(n)) if float(n).is_integer() else f'{n:g}'


def mark(score, points):
    if score >= points:
        return '✅'
    return '❌' if score == 0 else '🔺'


def load_set(s):
    qs = []
    for d in sorted(glob.glob(os.path.join(ROOT, f'mock_exam_{s}', 'q*', ''))):
        q = read_question(os.path.join(d, 'question.md'))
        q['dir'] = os.path.basename(os.path.dirname(d))
        qs.append(q)
    return qs


def summarize(qs):
    firsts = [q for q in qs if q['attempts']]
    score = sum(q['attempts'][0]['score'] for q in firsts)
    minutes = sum(float(q['attempts'][0]['min'] or 0) for q in firsts)
    dates = sorted({q['attempts'][0]['date'] for q in firsts if q['attempts'][0]['date']})
    lost = {dm: 0.0 for dm in DOMAINS}
    got = {dm: 0.0 for dm in DOMAINS}
    for q in firsts:
        a = q['attempts'][0]['score']
        got[q['domain']] += a
        lost[q['domain']] += q['points'] - a
    return {
        'done': len(firsts), 'total': len(qs), 'score': score, 'minutes': minutes,
        'date': (dates[0] if len(dates) == 1 else f'{dates[0]} ~ {dates[-1]}') if dates else '',
        'got': got, 'lost': lost,
    }


def score_text(sm):
    if not sm['done']:
        return '/ 100'
    t = f"{fmt(sm['score'])} / 100"
    if sm['done'] < sm['total']:
        t += f" · {sm['total']}문항 중 {sm['done']}문항"
    return t


def update_set_readme(s, qs, sm):
    path = os.path.join(ROOT, f'mock_exam_{s}', 'README.md')
    lines = open(path, encoding='utf-8').read().split('\n')
    by_dir = {q['dir']: q for q in qs}
    section = None
    for i, line in enumerate(lines):
        if line.startswith('## '):
            section = line[3:].strip()
        if not line.startswith('|') or line.startswith('|---'):
            continue
        cs = cells(line)
        if section is None and cs[0] == '응시일':
            lines[i] = row([cs[0], sm['date']])
        elif section is None and cs[0] == '실제 소요':
            lines[i] = row([cs[0], f"{fmt(sm['minutes'])}분" if sm['done'] else ''])
        elif section is None and cs[0] == '점수':
            lines[i] = row([cs[0], f"{score_text(sm)} (합격선 {PASS})"])
        elif section == '문항' and len(cs) == 8:
            m = re.search(r'\]\((q\d\d_[^/]+)/question\.md\)', cs[7])
            if m:
                q = by_dir[m.group(1)]
                if q['attempts']:
                    a0 = q['attempts'][0]
                    res = f"{mark(a0['score'], q['points'])} {fmt(a0['score'])}"
                    if len(q['attempts']) > 1:
                        last = q['attempts'][-1]
                        res += f" · 복습 {len(q['attempts']) - 1}회 {mark(last['score'], q['points'])}"
                    cs[5] = f"{a0['min']}분" if a0['min'] else ''
                    cs[6] = res
                else:
                    cs[5], cs[6] = '', '☐'
                lines[i] = row(cs)
            elif '**합계**' in cs[1]:
                cs[5] = f"**{fmt(sm['minutes'])}분**" if sm['done'] else ''
                cs[6] = f"**{fmt(sm['score'])}**" if sm['done'] else ''
                lines[i] = row(cs)
        elif section == '도메인별 실점' and cs[0] in DOMAINS:
            cs[4] = fmt(sm['got'][cs[0]]) if sm['done'] else ''
            cs[5] = fmt(sm['lost'][cs[0]]) if sm['done'] else ''
            lines[i] = row(cs)
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))


def update_root_readme(sums):
    path = os.path.join(ROOT, 'README.md')
    lines = open(path, encoding='utf-8').read().split('\n')
    section = None
    for i, line in enumerate(lines):
        if line.startswith('## '):
            section = line[3:].strip()
        if not line.startswith('|') or line.startswith('|-') or line.startswith('| -'):
            continue
        cs = cells(line)
        if section == '진행 현황' and len(cs) == 9:
            m = re.search(r'mock_exam_([a-f])', cs[0])
            if m:
                sm = sums[m.group(1)]
                cs[4] = sm['date']
                cs[5] = f"{fmt(sm['minutes'])}분" if sm['done'] else ''
                cs[6] = score_text(sm)
                if sm['done'] == sm['total']:
                    cs[7] = '✅' if sm['score'] >= PASS else '❌'
                else:
                    cs[7] = '☐'
                lines[i] = row(cs)
        elif section == '도메인별 자신감' and cs[0] in DOMAINS:
            for k, s in enumerate(SETS):
                sm = sums[s]
                cs[2 + k] = fmt(sm['lost'][cs[0]]) if sm['done'] else ''
            lines[i] = row(cs)
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))


def main():
    sums = {}
    for s in SETS:
        qs = load_set(s)
        sums[s] = summarize(qs)
        update_set_readme(s, qs, sums[s])
    update_root_readme(sums)
    for s in SETS:
        sm = sums[s]
        print(f"mock_exam_{s}: {sm['done']}/{sm['total']}문항, {score_text(sm)}")


if __name__ == '__main__':
    main()
