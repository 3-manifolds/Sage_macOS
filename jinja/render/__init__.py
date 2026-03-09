from jinja2 import Environment, FileSystemLoader
import os, subprocess, stat, time, datetime, tempfile, requests
rwxr_xr_x = stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH

class JinjaMaster:
    def __init__(self, template_dir, params={}):
        if not os.path.isdir(template_dir):
            raise RuntimeError('No template directory.')
        self.template_dir = template_dir
        self.params = params
        os.makedirs('output', exist_ok=True)

    def make_rtf(self, basename):
        """
        Generates an RTF file from an html template.
        """
        loader = FileSystemLoader(self.template_dir)
        env = Environment(loader=loader)
        template = env.get_template(basename + '.jinja2')
        tempdir = tempfile.TemporaryDirectory()
        html_filename = os.path.join(tempdir.name, basename + '.html')
        with open(html_filename, 'w') as html_file:
            html_file.write(template.render(self.params))
        subprocess.call(['textutil', '-convert', 'rtf', '-output',
                             'output/%s.rtf'%basename,
                             html_filename])

    def make_script(self, name):
        """
        Generates an executable script.
        """
        loader = FileSystemLoader(self.template_dir)
        env = Environment(loader=loader)
        template = env.get_template(name + '.jinja2')
        with open('output/%s'%name, 'w') as output:
            output.write(template.render(self.params))
        os.chmod('output/%s'%name, rwxr_xr_x)

    def make_file(self, name):
        """
        Generates a file with specified extension from a template
        with the same basename.
        """
        basename, extension = os.path.splitext(name)
        loader = FileSystemLoader(self.template_dir)
        env = Environment(loader=loader)
        template = env.get_template(basename + '.jinja2')
        with open('output/%s'%name, 'w') as output:
            output.write(template.render(self.params))

# Our github tags had major number 1 for the 9.X versions of SageMath and major
# number 2 for the 10.X versions.  The minor numbers were the same the our
# patch number counted releases of the same Sage version.  Starting with Sage 10.9
# we will use the same major and minor numbers as Sage and our patch number
# will count releases of the same version of Sage. Note that Sage does not use
# a patch number, except for beta and release candidates.

def main(sage_version='10.1', python_version='3.11.1'):
    dashed = sage_version.replace('.', '-')
    api_url='https://api.github.com/repos/3-manifolds/Sage_macOS/releases/latest'
    latest_tag = requests.get(api_url).json()['tag_name'][1:] # remove the letter v.
    tag_major, tag_minor, tag_patch = latest_tag.split('.')
    tag_major = int(tag_major)
    tag_minor = int(tag_minor)
    # We introduce pre-release parts of the patch component of the github tag with a dash.
    patch_parts = tag_patch.split('-')
    tag_patch = int(patch_parts[0])
    pre_release = partch_parts[1] if len(patch_parts) > 1 else ''
    if int(tag_major) <= 2:
        tag_major += 8
    # Sage uses the patch only for pre-releases
    sage_major, sage_minor = [int(x) for x in sage_version.split('.')[:2]]
    if sage_major > tag_major:
        tag_major = sage_major
        tag_minor = sege_minor
    elif sage_minor > tag_minor:
        tag_minor = sage_minor
        tag_patch = 0
    elif not pre_release:
        # major and minor agree, so this is a patch release or a pre-release
        tag_patch += 1
    github_tag = f'{tag_major}.{tag_minor}.{tag_patch}'
    params={
        'python_version': python_version,
        'sage_version': sage_version,
        'sage_dash_version': dashed,
        'github_tag': github_tag,
        'timestamp': str(int(time.time())),
        'year': str(datetime.datetime.now().year),
        }
    JM = JinjaMaster('templates', params)
    JM.make_rtf('Welcome')
    JM.make_script('sage')
    JM.make_file('kernel.json')
    JM.make_file('Info.plist')
    JM.make_file('Distribution')
    JM.make_file('pyvenv.cfg')

