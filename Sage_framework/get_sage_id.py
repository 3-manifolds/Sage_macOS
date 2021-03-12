import sys
import re
get_uuid = re.compile('p = SearchAndReplace.*SageMath/([a-z0-9]+)')
get_uuid_line = re.compile("p =.+/[a-z0-9]+")
with open('SageMath/relocate-once.py') as input_file:
    lines = get_uuid_line.findall(input_file.read())
m = get_uuid.match(lines[0])
print(m.groups()[0])

    
