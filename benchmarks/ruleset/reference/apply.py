"""Applies the reference answer to a copy of the library project - to check that grade.py gives it every point.

usage: python apply.py PROJECT
Copies library-rules/ into PROJECT with the root build's ElastiCORE version, includes it in
settings.gradle, names the rule class in the elasticore { } block, puts the module on the generator's
classpath, and marks Member.email @pii and Book @nodelete in the model.
"""
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
project = sys.argv[1]


def edit(path, change):
    text = open(path, encoding="utf-8").read()
    new = change(text)
    if new == text:
        sys.exit("nothing changed in " + path)
    open(path, "w", encoding="utf-8", newline="").write(new)


build = os.path.join(project, "build.gradle")
version = re.search(r"id 'io\.elasticore' version '([^']+)'", open(build, encoding="utf-8").read()).group(1)
module = os.path.join(project, "library-rules")
shutil.copytree(os.path.join(HERE, "library-rules"), module)
edit(os.path.join(module, "build.gradle"), lambda t: t.replace("VERSION", version))
edit(os.path.join(project, "settings.gradle"), lambda t: t.rstrip() + "\ninclude 'library-rules'\n")
edit(build, lambda t: re.sub(r"(elasticore \{\n)", r"\1    rules = ['com.acme.rules.LibraryRules']\n", t, count=1))
edit(build, lambda t: re.sub(r"(dependencies \{\n)", r"\1    elasticore project(':library-rules')\n", t, count=1))
model = os.path.join(project, "src", "main", "resources", "blueprint", "library", "model", "entity.yml")
edit(model, lambda t: t.replace("@email -- e-mail address", "@email @pii -- e-mail address"))
edit(model, lambda t: t.replace("@sort(title+) -- book", "@sort(title+) @nodelete -- book"))
print("applied, ElastiCORE " + version)
