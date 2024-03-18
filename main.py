import sys
import re
import os
from os.path import pardir, abspath, join as path_join
import subprocess
import signal
import json
import time
import plistlib
import webbrowser
import tkinter
from tkinter import ttk
from tkinter.font import Font
from tkinter.simpledialog import Dialog, askstring
from tkinter.filedialog import askdirectory
from tkinter.messagebox import showerror, showwarning, askyesno, askokcancel
from tkinter.scrolledtext import ScrolledText
from sage.version import version as sage_version
import os
import plistlib
import platform

this_python = 'python' + '.'.join(platform.python_version_tuple()[:2])
contents_dir = abspath(path_join(sys.argv[0], pardir, pardir))
framework_dir = path_join(contents_dir, 'Frameworks')
info_plist = path_join(contents_dir, 'Info.plist')
current = path_join(framework_dir, 'Sage.framework', 'Versions', 'Current')
sage_executable =  path_join(current, 'venv', 'bin', 'sage')
sage_jupyter_path = path_join(current, 'venv', 'share', 'jupyter')
sage_userbase = path_join(os.environ['HOME'], '.sage', 'local')
sage_userlib = path_join(sage_userbase, 'lib', this_python)
sage_usersitepackages = path_join(sage_userlib, 'site-packages')

def get_version():
    with open(info_plist, 'rb') as plist_file:
        info = plistlib.load(plist_file)
    return info['CFBundleShortVersionString']

sagemath_version = get_version()
app_name = 'SageMath-%s' % sagemath_version.replace('.', '-')
app_support_dir = path_join(os.environ['HOME'], 'Library', 'Application Support',
                                    app_name)
settings_path = path_join(app_support_dir, 'Settings.plist')
jupyter_runtime_dir = os.path.join(app_support_dir, 'Jupyter', 'runtime')
jp_pid_re = re.compile('jpserver-([0-9]*).*')

class PopupMenu(ttk.Menubutton):
    def __init__(self, parent, variable, values):
        ttk.Menubutton.__init__(self, parent, textvariable=variable,
                                    direction='flush')
        self.parent = parent
        self.variable = variable
        self.update(values)

    def update(self, values):
        self.variable.set(values[0])
        self.menu = tkinter.Menu(self.parent, tearoff=False)
        for value in values:
            self.menu.add_radiobutton(label=value, variable=self.variable)
        self.config(menu=self.menu)

class Launcher:
    jp_json_re = re.compile('jpserver-[0-9]*\.json')
    url_fmt = 'http://localhost:{port}/{nb_type}?token={token}'
    sage_cmd = 'clear ; %s ; exit'%sage_executable
    terminal_script = """
        set command to "%s"
        tell application "System Events"
            set terminalProcesses to application processes whose name is "Terminal"
        end tell
        if terminalProcesses is {} then
            set terminalIsRunning to false
        else
            set terminalIsRunning to true
        end if
        if terminalIsRunning then
            tell application "Terminal"
                activate
                do script command
            end tell
        else
        -- avoid opening two windows
        tell application "Terminal"
            activate
            do script command in window 1
            end tell
        end if
    """%sage_cmd

    iterm_script = """
        set sageCommand to "/bin/bash -c '%s'"
        tell application "iTerm"
            set sageWindow to (create window with default profile command sageCommand)
            select sageWindow
        end tell
    """%sage_cmd

    find_app_script = """
        set appExists to false
        try
	        tell application "Finder" to get application file id "%s"
            set appExists to true
        end try
        return appExists
    """

    def check_notebook_dir(self):
        notebook_dir = self.notebook_dir.get()
        if not notebook_dir.strip():
            showwarning(parent=self,
                message="Please choose or create a folder for your Jupyter notebooks.")
            return False
        if not os.path.exists(notebook_dir):
            answer = askyesno(message='May we create the folder %s?'%notebook_dir)
            if answer == tkinter.YES:
                os.makedirs(notebook_dir, exist_ok=True)
            else:
                return False
        try:
            os.listdir(notebook_dir)
        except:
            showerror(message='Sorry. We do not have permission to read %s'%directory)
            return False
        return True
            
    def find_app(self, bundle_id):
        script = self.find_app_script%bundle_id
        result = subprocess.run(['osascript', '-'], input=script, text=True,
                                    capture_output=True)
        return result.stdout.strip() == 'true' 

    def launch_terminal(self, app):
        if app == 'Terminal.app':
            subprocess.run(['osascript', '-'], input=self.terminal_script, text=True,
                               capture_output=True, env=os.environ)
        elif app == 'iTerm.app':
            subprocess.run(['open', '-a', 'iTerm'], capture_output=True)
            subprocess.run(['osascript', '-'], input=self.iterm_script, text=True,
                               capture_output=True)
        return True

    def launch_notebook(self, notebook_type):
        if not self.check_notebook_dir():
            return False
        notebook_dir = self.notebook_dir.get()
        environ = {'JUPYTER_RUNTIME_DIR': jupyter_runtime_dir,
                    'JUPYTER_PATH': sage_jupyter_path}
        environ.update(os.environ)
        json_files = [f for f in os.listdir(jupyter_runtime_dir)
                           if self.jp_json_re.match(f)]
        if json_files:
            filename = os.path.join(jupyter_runtime_dir, json_files[0])
            with open(filename) as json_file:
                info = json.load(json_file)
            info['nb_type'] = 'lab' if notebook_type=='jupyterlab' else 'tree'
            if info['root_dir'] == notebook_dir:
                url = self.url_fmt.format(**info)
                subprocess.run(['open', url], env=environ)
                return True
        sage_executable = path_join(framework_dir, 'sage.framework', 'Versions',
                                    'Current', 'venv', 'bin', 'sage')
        subprocess.Popen([sage_executable, '-n', notebook_type,
                          '--notebook-dir=%s'%notebook_dir], env=environ)
        return True

class LaunchWindow(tkinter.Toplevel, Launcher):

    def __init__(self, root):
        Launcher.__init__(self)
        self.get_settings()
        self.root = root
        tkinter.Toplevel.__init__(self)
        self.tk.call('::tk::unsupported::MacWindowStyle', 'style', self._w,
                         'document', 'closeBox')
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.title('SageMath')
        self.columnconfigure(0, weight=1)
        frame = ttk.Frame(self, padding=10, width=300)
        frame.columnconfigure(0, weight=1)
        frame.grid(row=0, column=0, sticky='nsew')
        self.update_idletasks()
	# Logo
        resource_dir = abspath(path_join(sys.argv[0], pardir, pardir,
            'Resources'))
        logo_file = path_join(resource_dir, 'sage_logo_256.png')
        try:
            self.logo_image = tkinter.PhotoImage(file=logo_file)
            logo = ttk.Label(frame, image=self.logo_image)
        except tkinter.TclError:
            logo = ttk.Label(frame, text='Logo Here')
	# Interfaces
        interfaces = ttk.Labelframe(frame, text="Available User Interfaces",
            padding=10)
        self.radio_var = radio_var = tkinter.Variable(interfaces,
            self.settings['state']['interface_type'])
        self.use_cli = ttk.Radiobutton(interfaces, text="Command line",
            variable=radio_var, value='cli',
            command=self.update_radio_buttons)
        self.terminals = ['Terminal.app']
        if self.find_app('com.googlecode.iterm2'):
            if self.settings['state']['terminal_app'] == 'iTerm.app':
                self.terminals.insert(0, 'iTerm.app')
            else:
                self.terminals.append('iTerm.app')
        self.terminal_var = tkinter.Variable(self, self.terminals[0])
        self.terminal_option = PopupMenu(interfaces,
            self.terminal_var, self.terminals)
        self.use_jupyter = ttk.Radiobutton(interfaces, text="Notebook",
            variable=radio_var, value='nb',  command=self.update_radio_buttons)
        self.notebook_types = ['Jupyter Notebook', 'JupyterLab']
        favorite = self.settings['state']['notebook_type']
        if favorite != 'Jupyter Notebook' and favorite in self.notebook_types:
            self.notebook_types.remove(favorite)
            self.notebook_types.insert(0, favorite)
        self.nb_var = tkinter.Variable(self, self.notebook_types[0])
        self.notebook_option = PopupMenu(interfaces, self.nb_var,
            self.notebook_types)
        notebook_dir_frame = ttk.Frame(interfaces)
        ttk.Label(notebook_dir_frame, text='Using notebooks from:').grid(
            row=0, column=0, sticky='w', padx=12)
        self.notebook_dir = ttk.Entry(notebook_dir_frame, width=24)
        self.notebook_dir.insert(tkinter.END, self.settings['state']['notebook_dir'])
        self.notebook_dir.config(state='readonly')
        self.browse = ttk.Button(notebook_dir_frame, text='Select ...', padding=(-8, 0),
            command=self.browse_notebook_dir, state=tkinter.DISABLED)
        self.notebook_dir.grid(row=1, column=0, padx=8)
        self.browse.grid(row=1, column=1)
    # Build the interfaces frame
        self.use_cli.grid(row=0, column=0, sticky='w', pady=5)
        self.terminal_option.grid(row=1, column=0, sticky='w', padx=10, pady=5)
        self.use_jupyter.grid(row=2, column=0, sticky='w', pady=5)
        self.notebook_option.grid(row=3, column=0, sticky='w', padx=10, pady=5)
        notebook_dir_frame.grid(row=4, column=0, sticky='w', pady=5)
    # Launch button
        launch_frame = ttk.Frame(frame)
        self.launch = ttk.Button(launch_frame, text="Launch", command=self.launch_sage)
        self.launch.pack()
	# Build the window
        logo.grid(row=0, column=0, pady=5)
        interfaces.grid(row=2, column=0, padx=10, pady=10, sticky='ew')
        launch_frame.grid(row=3, column=0)
        self.geometry('380x390+400+400')
        self.update_radio_buttons()
        self.update_idletasks()

    def close(self):
        self.withdraw()

    default_settings = {
        'environment': {
        },
        'state': {
            'interface_type': 'cli',
            'terminal_app': 'Terminal.app',
            'notebook_type': 'Jupyter Notebook',
            'notebook_dir': '',
        },
    }

    def get_settings(self):
        # The settings are described by a dict with dict values.
        settings = self.default_settings.copy()
        try:
            with open(settings_path, 'rb') as settings_file:
                saved_settings = plistlib.load(settings_file)
        except:
            #settings file missing or corrupt
            saved_settings = None
        if saved_settings:
            for key in settings:
                settings[key].update(saved_settings.get(key, {}))
        self.settings = settings
        
    def save_settings(self):
        self.get_settings()
        self.settings['state'].update(
            {
                'interface_type': self.radio_var.get(),
                'terminal_app': self.terminal_var.get(),
                'notebook_type': self.nb_var.get(),
                'notebook_dir': self.notebook_dir.get(),
            }
        )
        try:
            with open(settings_path, 'wb') as settings_file:
                plistlib.dump(self.settings, settings_file)
        except:
            pass

    def update_radio_buttons(self):
        radio = self.radio_var.get()
        if radio == 'cli':
            self.notebook_dir.config(state=tkinter.DISABLED)
            self.browse.config(state=tkinter.DISABLED)
            self.terminal_option.config(state=tkinter.NORMAL)
            self.notebook_option.config(state=tkinter.DISABLED)
        elif radio == 'nb':
            self.notebook_dir.config(state='readonly')
            self.browse.config(state=tkinter.NORMAL)
            self.notebook_option.config(state=tkinter.NORMAL)
            self.terminal_option.config(state=tkinter.DISABLED)

    def update_environment(self):
        required_paths = [
        '/var/tmp/sage-10.3-current/local/bin',
        '/var/tmp/sage-10.3-current/venv/bin',
        '/bin',
        '/usr/bin',
        '/usr/local/bin',
        '/Library/TeX/texbin'
        ]
        try:
            with open(settings_path, 'rb') as settings_file:
                settings = plistlib.load(settings_file)
                environment = settings.get('environment', {})
        except:
            environment = {}
        # Try to prevent users from crippling Sage with a weird PATH.
        user_paths = environment.get('PATH', '').split(':')
        # Avoid including the empty path.
        paths = [path for path in user_paths if path] + required_paths
        unique_paths = list(dict.fromkeys(paths))
        environment['PATH'] = ':'.join(unique_paths)
        os.environ.update(environment)
            
    def launch_sage(self):
        self.update_environment()
        interface = self.radio_var.get()
        if interface == 'cli':
            launched = self.launch_terminal(app=self.terminal_var.get())
        elif interface == 'nb':
            app = self.nb_var.get()
            if not app in self.notebook_types:
                app = 'Jupyter Notebook'
                self.nb_var.set(app)
            if app == 'JupyterLab':
                launched = self.launch_notebook('jupyterlab')
            else:
                launched = self.launch_notebook('jupyter')
        if launched:
            self.save_settings()
            self.close()

    def browse_notebook_dir(self):
        directory = askdirectory(parent=self, initialdir=os.environ['HOME'],
            message='Choose or create a folder for Jupyter notebooks')
        if directory:
            self.notebook_dir.config(state=tkinter.NORMAL)
            self.notebook_dir.delete(0, tkinter.END)
            self.notebook_dir.insert(tkinter.END, directory)
            self.notebook_dir.config(state='readonly')
            
class AboutDialog(Dialog):
    def __init__(self, parent, title='', content=''):
        self.content = content
        self.style = ttk.Style(parent)
        resource_dir = abspath(path_join(sys.argv[0], pardir, pardir, 'Resources'))
        logo_file = path_join(resource_dir, 'sage_logo_256.png')
        try:
            self.logo_image = tkinter.PhotoImage(file=logo_file)
        except tkinter.TclError:
            self.logo_image = None
        Dialog.__init__(self, parent, title=title)
        
    def body(self, parent):
        self.resizable(False, False)
        frame = ttk.Frame(self)
        if self.logo_image:
            logo = ttk.Label(frame, image=self.logo_image)
        else:
            logo = ttk.Label(frame, text='Logo Here')
        logo.grid(row=0, column=0, padx=20, pady=20, sticky='n')
        message = tkinter.Message(frame, text=self.content)
        message.grid(row=1, column=0, padx=20, sticky='ew')
        frame.pack()

    def buttonbox(self):
        frame = ttk.Frame(self, padding=(0, 0, 0, 20))
        ok = ttk.Button(frame, text="OK", width=10, command=self.ok,
                            default=tkinter.ACTIVE)
        ok.grid(row=2, column=0, padx=5, pady=5)
        self.bind("<Return>", self.ok)
        self.bind("<Escape>", self.ok)
        frame.pack()

class InfoDialog(Dialog):
    def __init__(self, parent, title='', message='',
                     text_width=40, text_height=12, font_size=16):
        self.message = message
        self.text_width, self.text_height = text_width, text_height
        self.text_font = tkinter.font.Font()
        self.text_font.config(size=font_size)
        self.style = ttk.Style(parent)
        resource_dir = abspath(path_join(sys.argv[0], pardir, pardir, 'Resources'))
        logo_file = path_join(resource_dir, 'sage_logo_256.png')
        try:
            self.logo_image = tkinter.PhotoImage(file=logo_file)
        except tkinter.TclError:
            self.logo_image = None
        Dialog.__init__(self, parent, title=title)
        
    def body(self, parent):
        self.resizable(False, False)
        frame = ttk.Frame(self)
        if self.logo_image:
            logo = ttk.Label(frame, image=self.logo_image)
        else:
            logo = ttk.Label(frame, text='Logo Here')
        logo.grid(row=0, column=0, padx=20, pady=20, sticky='n')
        font = tkinter.font.Font()
        font.config(size=18)
        text = tkinter.Text(frame, wrap=tkinter.WORD, bd=0,
            highlightthickness=0, bg='SystemWindowBackgroundColor',
            width=self.text_width, height=self.text_height,
            font=self.text_font)
        text.grid(row=1, column=0, padx=20, sticky='ew')
        text.insert(tkinter.INSERT, self.message)
        text.config(state=tkinter.DISABLED)
        frame.pack()

    def buttonbox(self):
        frame = ttk.Frame(self, padding=(0, 0, 0, 20))
        ok = ttk.Button(frame, text="OK", width=10, command=self.ok,
                            default=tkinter.ACTIVE)
        ok.grid(row=2, column=0, padx=5, pady=5)
        self.bind("<Return>", self.ok)
        self.bind("<Escape>", self.ok)
        frame.pack()

class EnvironmentEditor(tkinter.Toplevel):
    def __init__(self, parent):
        tkinter.Toplevel.__init__(self, parent)
        self.parent = parent
        self.wm_protocol('WM_DELETE_WINDOW', self.close)
        self.title('Sage Environment')
        home = os.environ['HOME']
        self.load_settings()
        self.environment = self.settings.get('environment', {})
        self.varlist = list(self.environment.keys())
        self.add = tkinter.Image('nsimage', name='add', source='NSAddTemplate',
                        width=20, height=20)
        self.remove = tkinter.Image('nsimage', name='remove', source='NSRemoveTemplate',
                        width=20, height=4)
        self.left = ttk.Frame(self, padding=0)
        ttk.Label(self, text = 'Variable').grid(row=0, column=0, padx=10, sticky='w')
        ttk.Label(self, text = 'Value').grid(row=0, column=1, sticky='w')
        self.varnames = tkinter.StringVar(self)
        if self.varlist:
            self.varnames.set(self.varlist)
        self.listbox = tkinter.Listbox(self.left, selectmode='browse',
                          listvariable=self.varnames, height=19)
        self.listbox.grid(row=1, column=0, columnspan=2, sticky='nsew')
        button_frame = ttk.Frame(self.left, padding=(0, 4, 0, 10))
        ttk.Button(button_frame, style="GradientButton", image='add',
            command=self.add_var).grid(row=0, column=0, sticky='nw')
        ttk.Button(button_frame, style="GradientButton", image='remove',
            padding=(0,8), command=self.remove_var).grid(row=0, column=1, sticky='nw')
        button_frame.grid(row=2, column=0, sticky='nw')
        self.columnconfigure(1, weight=1)
        self.rowconfigure(1, weight=1)
        self.left.grid(row=1, rowspan=2, column=0, sticky='nsw', padx=10, pady=10)
        self.text = ScrolledText(self)
        self.text.frame.grid(row=1, column=1, pady=10, sticky='nsew')
        ttk.Button(self, text='Done', command = self.done).grid(
            row=2, column=1, pady=20, padx=20, sticky='es')
        self.listbox.bind("<<ListboxSelect>>",
            lambda e: self.update())
        self.selected = None
        if self.varlist:
            self.listbox.selection_set(0)
            self.update()

    def update(self):
        if self.selected is not None:
            current_value = self.text.get('0.0', 'end').strip()
            self.environment[self.listbox.get(self.selected)] = current_value
        selection = self.listbox.curselection()
        if not selection:
            return
        selection = selection[0]
        self.selected = selection
        self.text.delete('0.0', 'end')
        var = self.listbox.get(selection).strip()
        value = self.environment.get(var, '')
        if value:
            self.text.insert('0.0', value)

    def add_var(self):
        self.update()
        new_var = askstring('New Variable', 'Variable Name:')
        self.environment[new_var] = ''
        self.text.delete('0.0', 'end')
        self.selected = len(self.varlist)
        self.varlist.append(new_var)
        self.listbox.insert('end', new_var)
        self.listbox.selection_clear(0, 'end')
        self.listbox.selection_set(self.selected)
        self.listbox.see(self.selected)
        self.text.focus_set()

    def remove_var(self):
        selection = self.listbox.curselection()
        if not selection:
            return
        var = self.listbox.get(selection[0])
        self.varlist.remove(var)
        self.environment.pop(var)
        self.text.delete('0.0', 'end')
        self.varnames.set(self.varlist)
        if '' in self.environment:
            self.environment.pop('')

    def go(self):
        self.transient(self.parent)
        self.grab_set()
        self.wait_window(self)

    def load_settings(self):
        if os.path.exists(settings_path):
            try:
                with open(settings_path, 'rb') as settings_file:
                    self.settings = plistlib.load(settings_file)
            except plistlib.InvalidFileException:
                os.unlink(settings_path)
                self.settings = {}
        else:
            self.settings = {}

    def done(self):
        self.update()
        if '' in self.environment:
            self.environment.pop('')
        self.settings['environment'] = self.environment
        with open(settings_path, 'wb') as settings_file:
            plistlib.dump(self.settings, settings_file)
        self.destroy()

    def close(self):
        if askokcancel(message=''
            'Closing the window will cause your changes to be lost.'):
            self.destroy()

class SageApp(Launcher):
    resource_dir = abspath(path_join(sys.argv[0], pardir, pardir, 'Resources'))
    icon_file = abspath(path_join(resource_dir, 'sage_icon_1024.png'))
    about = """
SageMath is a free open-source mathematics software system licensed under the GPL. Please visit sagemath.org for more information about SageMath.

This SageMath app contains a subset of the SageMath binary distribution available from sagemath.org. It is packaged as a component of the 3-manifolds project by Marc Culler, Nathan Dunfield, and Matthias Gӧrner.  It is licensed under the GPL License, version 2 or later, and can be downloaded from
https://github.com/3-manifolds/Sage_macOS/releases.

The app is copyright © 2021 by Marc Culler, Nathan Dunfield, Matthias Gӧrner and others.
"""

    def __init__(self):
        os.makedirs(app_support_dir, exist_ok=True)
        os.makedirs(jupyter_runtime_dir, exist_ok=True)
        self.root_window = root = tkinter.Tk()
        root.withdraw()
        os.chdir(os.environ['HOME'])
        self.icon = tkinter.Image("photo", file=self.icon_file)
        root.tk.call('wm','iconphoto', root._w, self.icon)
        self.menubar = menubar = tkinter.Menu(root)
        root.createcommand('::tk::mac::ShowPreferences', self.edit_env)
        apple_menu = tkinter.Menu(menubar, name="apple")
        apple_menu.add_command(label='About SageMath ...',
                                   command=self.about_sagemath)
        menubar.add_cascade(menu=apple_menu)
        root.config(menu=menubar)
        ttk.Label(root, text="SageMath").pack(padx=20, pady=20)

    def about_sagemath(self):
        AboutDialog(self.root_window, 'SageMath', self.about)

    def edit_env(self):
        editor = EnvironmentEditor(self.launcher)
        editor.go()

    def run(self):
        symlink = path_join(os.path.sep, 'var', 'tmp',
                                'sage-%s-current' % sagemath_version)
        self.launcher = LaunchWindow(root=self.root_window)
        if not os.path.islink(symlink):
            try:
                os.symlink(current, symlink)
            except Exception as e:
                showwarning(parent=self.root_window,
                    message="%s Cannot create %s; "
                            "SageMath must exit."%(e, symlink))
                sys.exit(1)
        self.root_window.createcommand('tk::mac::ReopenApplication',
                                      self.launcher.deiconify)
        self.root_window.createcommand('tk::mac::Quit', self.quit)
        self.root_window.mainloop()

    def shutdown_servers(self):
        try:
            jp_files = os.listdir(jupyter_runtime_dir)
        except:
            return
        pids = set()
        for filename in jp_files:
            m = jp_pid_re.match(filename)
            if m:
                pids.add(m.groups()[0])
        if pids:
            answer = askokcancel(
                message='Quitting the SageMath app will terminate '
                        'all notebooks.  Unsaved changes will be lost.')
            if answer == False:
                return False
            for pid in pids:
                try:
                    os.kill(int(pid), signal.SIGTERM)
                except:
                    pass
            for filename in jp_files:
                if filename == 'jupyter_cookie_secret':
                    continue
                if os.path.exists(filename):
                    os.unlink(filename)
        return True

    def quit(self):
        if self.shutdown_servers():
            self.launcher.destroy()
            self.root_window.destroy()
        
if __name__ == '__main__':
    SageApp().run()
