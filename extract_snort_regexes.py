import re
import os
import sys

def load_file(path):
    with open(path, 'r') as f:
        try:
            return f.read()
        except:
            return ""

def contains_unsupported(regex):
    return "(?=" in regex or "(?!" in regex or "(?P=" in regex or "(?>" in regex

def contains_lookbehind(regex):
    return "(?<=" in regex or "(?<!" in regex

def find_regexes(content):
    regexes = re.findall(".*?pcre:\"(.*?)\";", content)
    regexes = [regex for regex in regexes if contains_lookbehind(regex) and not contains_unsupported(regex)]
    return regexes

def enumerate_files(directory):
    result = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            result.append(os.path.join(root, file))
    result.sort()
    return result

def collect_regexes(directory):
    for path in enumerate_files(directory):
        content = load_file(path)
        regexes = find_regexes(content)
        yield from regexes

def rewrite_regex(regex):
    regex = re.findall(r"/(.*)/([ims]*)$", regex)
    flags = regex[0][1]
    regex = regex[0][0].replace('\\/', '/')
    regex = f"(?{flags}:{regex})"
    return regex

def write_regexes(regexes, directory):
    for i, regex in enumerate(regexes):
        with open(os.path.join(directory, f"snort_{i}.txt"), "w") as f:
            f.write(rewrite_regex(regex))

if __name__ == "__main__":
    args = sys.argv
    regexes = collect_regexes(args[1])
    write_regexes(regexes, args[2])
