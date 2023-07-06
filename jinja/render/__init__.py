from jinja2 import Environment, FileSystemLoader
import os, subprocess, stat, datetime, tempfile
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

def main(sage_version='10.1', python_version='3.11.1'):
    dashed = sage_version.replace('.', '-')
    params={
        'python_version': python_version,
        'sage_version': sage_version,
        'sage_dash_version': dashed,
        'sage_long_version': sage_version + '.0',
        'year': str(datetime.datetime.now().year),
        }
    JM = JinjaMaster('templates', params)
    JM.make_rtf('Welcome')
    JM.make_script('sage')
    JM.make_file('kernel.json')
    JM.make_file('Info.plist')
    JM.make_file('Distribution')
    JM.make_file('pyvenv.cfg')

