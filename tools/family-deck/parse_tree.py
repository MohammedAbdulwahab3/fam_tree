import re, json, os, sys

# Resolved from this file rather than the working directory, so `npm run build`
# works from tools/family-deck as the README says.
SEED = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..', 'backend', 'seed', 'seed.go'
)

src = open(SEED).read()
start = src.index('var familyTreeNodes = []Node{')
# find the matching close of the slice literal
i = src.index('{', start)
depth, j = 0, i
while j < len(src):
    if src[j] == '{': depth += 1
    elif src[j] == '}':
        depth -= 1
        if depth == 0: break
    j += 1
body = src[i+1:j]

# Tokenise n("First", "Last", "gender", ...children...)
tok = re.compile(r'n\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"|[(),]')

def parse(text):
    """Recursive-descent over the n(...) calls."""
    nodes, pos = [], 0
    def rec(pos):
        out = []
        while pos < len(text):
            m = re.compile(r'n\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"').search(text, pos)
            if not m:
                return out, len(text)
            # is this n( inside our level? find the closing paren of this call
            k = m.end()
            depth = 1
            # walk from the '(' after n
            p = text.index('(', m.start())
            depth, q = 0, p
            while q < len(text):
                if text[q] == '(': depth += 1
                elif text[q] == ')':
                    depth -= 1
                    if depth == 0: break
                q += 1
            inner = text[m.end():q]
            kids, _ = rec(0) if 'n(' in inner else ([], 0)
            kids = parse_children(inner)
            out.append({'first': m.group(1), 'last': m.group(2),
                        'gender': m.group(3), 'children': kids})
            pos = q + 1
        return out, pos
    def parse_children(inner):
        res = []
        p = 0
        while True:
            m = re.compile(r'n\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"').search(inner, p)
            if not m: break
            op = inner.index('(', m.start())
            depth, q = 0, op
            while q < len(inner):
                if inner[q] == '(': depth += 1
                elif inner[q] == ')':
                    depth -= 1
                    if depth == 0: break
                q += 1
            res.append({'first': m.group(1), 'last': m.group(2),
                        'gender': m.group(3),
                        'children': parse_children(inner[m.end():q])})
            p = q + 1
        return res
    return parse_children(text)

tree = parse(body)
json.dump(tree, open(sys.argv[1], 'w'), indent=1, ensure_ascii=False)

def count(ns):
    return sum(1 + count(x['children']) for x in ns)
def depth(ns, d=1):
    return max([depth(x['children'], d+1) for x in ns if x['children']] + [d])
print('roots:', len(tree), 'people:', count(tree), 'depth:', depth(tree))
