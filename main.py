import sys
import re
import os
from os.path import pardir, abspath, join as path_join
import subprocess
import signal
import json
import time
import plistlib
import tkinter
#### from configparser import ConfigParser
from tkinter import ttk
from tkinter.font import Font
from tkinter.simpledialog import Dialog, askstring
from tkinter.filedialog import askdirectory
from tkinter.messagebox import showerror, showwarning, askyesno, askokcancel
from tkinter.scrolledtext import ScrolledText
import os
import plistlib

jupyter_id = re.compile('nbserver-([0-9]+)-open.html')
contents_dir = abspath(path_join(sys.argv[0], pardir, pardir))
framework_dir = path_join(contents_dir, 'Frameworks')
info_plist = path_join(contents_dir, 'Info.plist')
current = path_join(framework_dir, 'Sage.framework', 'Versions', 'Current')
sage_executable =  path_join(current, 'venv', 'bin', 'sage')

def get_version():
    with open(info_plist, 'rb') as plist_file:
        info = plistlib.load(plist_file)
    return info['CFBundleShortVersionString']

sagemath_version = get_version()
app_support_dir = path_join(os.environ['HOME'], 'Library', 'Application Support',
                                    'SageMath')
# This must match what is used in ipython_extension.py
settings_path = path_join(app_support_dir, 'Settings.plist')

jupyter_runtime_dir = path_join(app_support_dir, 'Jupyter')
###config_file = path_join(app_support_dir, 'config')

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

    def launch_terminal(self, app):
        if app == 'Terminal.app':
            subprocess.run(['osascript', '-'], input=self.terminal_script, text=True,
                               capture_output=True, env=os.environ)
        elif app == 'iTerm.app':
            subprocess.run(['open', '-a', 'iTerm'], capture_output=True)
            subprocess.run(['osascript', '-'], input=self.iterm_script, text=True,
                               capture_output=True)
        return True

    def launch_notebook(self, url=None):
        environ = {'JUPYTER_RUNTIME_DIR': jupyter_runtime_dir}
        environ.update(os.environ)
        if url is None:
            if not self.check_notebook_dir():
                return False
            jupyter_notebook_dir = self.notebooks.get()
            if not jupyter_notebook_dir:
                jupyter_notebook_dir = os.environ['HOME']
            subprocess.Popen([sage_executable, '--jupyter', 'notebook',
                     '--notebook-dir=%s'%jupyter_notebook_dir], env=environ)
        else:
            subprocess.run(['open', url], env=environ, capture_output=True)
        return True

    def find_app(self, bundle_id):
        script = self.find_app_script%bundle_id
        result = subprocess.run(['osascript', '-'], input=script, text=True,
                                    capture_output=True)
        return result.stdout.strip() == 'true' 

class LaunchWindow(tkinter.Toplevel, Launcher):
    def __init__(self, root):
        Launcher.__init__(self)
        self.get_settings()
        self.root = root
        tkinter.Toplevel.__init__(self)
        self.tk.call('::tk::unsupported::MacWindowStyle', 'style', self._w,
                         'document', 'closeBox')
        self.protocol("WM_DELETE_WINDOW", self.quit)
        self.title('SageMath')
        self.columnconfigure(0, weight=1)
        frame = ttk.Frame(self, padding=10, width=300)
        frame.columnconfigure(0, weight=1)
        frame.grid(row=0, column=0, sticky=tkinter.NSEW)
        self.update_idletasks()
	# Logo
        resource_dir = abspath(path_join(sys.argv[0], pardir, pardir, 'Resources'))
        logo_file = path_join(resource_dir, 'sage_logo_256.png')
        try:
            self.logo_image = tkinter.PhotoImage(file=logo_file)
            logo = ttk.Label(frame, image=self.logo_image)
        except tkinter.TclError:
            logo = ttk.Label(frame, text='Logo Here')
	# Interfaces
        checks = ttk.Labelframe(frame, text="Available User Interfaces", padding=10)
        self.radio_var = radio_var = tkinter.Variable(checks,
                                         self.settings['state']['interface_type'])
        self.use_cli = ttk.Radiobutton(checks, text="Command line", variable=radio_var,
            value='cli', command=self.update_radio_buttons)
        self.terminals = ['Terminal.app']
        if self.find_app('com.googlecode.iterm2'):
            if self.settings['state']['terminal_app'] == 'iTerm.app':
                self.terminals.insert(0, 'iTerm.app')
            else:
                self.terminals.append('iTerm.app')
        self.terminal_var = tkinter.Variable(self, self.terminals[0])
        self.terminal_option = PopupMenu(checks, self.terminal_var, self.terminals)
        self.use_jupyter = ttk.Radiobutton(checks, text="Jupyter notebook from folder:",
            variable=radio_var, value='nb',  command=self.update_radio_buttons)
        notebook_frame = ttk.Frame(checks)
        self.notebooks = ttk.Entry(notebook_frame, width=24)
        self.notebooks.insert(tkinter.END, self.settings['state']['notebook_dir'])
        self.notebooks.config(state='readonly')
        self.browse = ttk.Button(notebook_frame, text='Select ...', padding=(-8, 0),
            command=self.browse_notebook_dir, state=tkinter.DISABLED)
        self.notebooks.grid(row=0, column=0)
        self.browse.grid(row=0, column=1)
	# Launch button
        self.launch = ttk.Button(frame, text="Launch", command=self.launch_sage)
    # Build the interfaces frame
        self.use_cli.grid(row=0, column=0, sticky=tkinter.W, pady=5)
        self.terminal_option.grid(row=1, column=0, sticky=tkinter.W, padx=10, pady=5)
        self.use_jupyter.grid(row=2, column=0, sticky=tkinter.W, pady=5)
        notebook_frame.grid(row=3, column=0, sticky=tkinter.W, pady=5)
	# Build the window
        logo.grid(row=0, column=0, pady=5)
        checks.grid(row=1, column=0, padx=10, pady=10, sticky=tkinter.EW)
        self.launch.grid(row=2, column=0)
        self.geometry('380x350+400+400')
        self.update_radio_buttons()
        
    def quit(self):
        self.destroy()
        self.root.destroy()

    def get_settings(self):
        try:
            with open(settings_path, 'rb') as settings_file:
                self.settings = plistlib.load(settings_file)
        except:
            self.settings = {}
        if 'state' not in self.settings:
            self.settings['state'] = {
                'interface_type': 'cli',
                'terminal_app': 'Terminal.app',
                'notebook_dir': '',
                }

    def save_settings(self):
        self.settings['state'] = {
            'interface_type': self.radio_var.get(),
            'terminal_app': self.terminal_var.get(),
            'notebook_dir': self.notebooks.get(),
            }
        with open(settings_path, 'wb') as settings_file:
            plistlib.dump(self.settings, settings_file)
            
    def update_radio_buttons(self):
        radio = self.radio_var.get()
        if radio == 'cli':
            self.notebooks.config(state=tkinter.DISABLED)
            self.browse.config(state=tkinter.DISABLED)
            self.terminal_option.config(state=tkinter.NORMAL)
        elif radio == 'nb':
            self.notebooks.config(state='readonly')
            self.browse.config(state=tkinter.NORMAL)
            self.terminal_option.config(state=tkinter.DISABLED)
        
    def launch_sage(self):
        # The settings may have changed!
        self.get_settings()
        environment = self.settings.get('environment', {})
        os.environ.update(environment)
        interface = self.radio_var.get()
        if interface == 'cli':
            launched = self.launch_terminal(app=self.terminal_var.get())
        elif interface == 'nb':
            jupyter_openers = [f for f in os.listdir(jupyter_runtime_dir)
                                   if f[-4:] == 'html']
            if not jupyter_openers:
                launched = self.launch_notebook(None)
            else:
                html_file = path_join(jupyter_runtime_dir, jupyter_openers[0]) 
                launched = self.launch_notebook(html_file)
        if launched:
            self.save_settings()
            self.quit()

    def check_notebook_dir(self):
        notebook_dir = self.notebooks.get()
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
            
    def browse_notebook_dir(self):
        json_files = [filename for filename in os.listdir(jupyter_runtime_dir)
                          if os.path.splitext(filename)[1] == '.json']
        if json_files:
            answer = askyesno(message='You already have a Jupyter server running with '
                                  'the notebook directory shown.  Do you want to stop '
                                  'that server and start a new one?')
            if answer == tkinter.YES:
                for json_file in json_files:
                    with open(os.path.join(jupyter_runtime_dir, json_file)) as in_file:
                        try:
                            pid = int(json.load(in_file)['pid'])
                            os.kill(pid, signal.SIGINT)
                            time.sleep(2)
                            os.kill(pid, signal.SIGINT)
                        except:
                            pass
            else:
                return
        directory = askdirectory(parent=self, initialdir=os.environ['HOME'],
            message='Choose or create a folder for Jupyter notebooks')
        if directory:
            self.notebooks.config(state=tkinter.NORMAL)
            self.notebooks.delete(0, tkinter.END)
            self.notebooks.insert(tkinter.END, directory)
            self.notebooks.config(state='readonly')
            
class AboutDialog(Dialog):
    def __init__(self, master, title='', content=''):
        self.content = content
        self.style = ttk.Style(master)
        resource_dir = abspath(path_join(sys.argv[0], pardir, pardir, 'Resources'))
        logo_file = path_join(resource_dir, 'sage_logo_256.png')
        try:
            self.logo_image = tkinter.PhotoImage(file=logo_file)
        except tkinter.TclError:
            self.logo_image = None
        Dialog.__init__(self, master, title=title)
        
    def body(self, master):
        self.resizable(False, False)
        frame = ttk.Frame(self)
        if self.logo_image:
            logo = ttk.Label(frame, image=self.logo_image)
        else:
            logo = ttk.Label(frame, text='Logo Here')
        logo.grid(row=0, column=0, padx=20, pady=20, sticky=tkinter.N)
        message = tkinter.Message(frame, text=self.content)
        message.grid(row=1, column=0, padx=20, sticky=tkinter.EW)
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
        ttk.Label(self, text = 'Variable').grid(row=0, column=0, padx=10, sticky='W')
        ttk.Label(self, text = 'Value').grid(row=0, column=1, sticky='W')
        self.varnames = tkinter.StringVar(self)
        if self.varlist:
            self.varnames.set(self.varlist)
        self.listbox = tkinter.Listbox(self.left, selectmode='browse',
                          listvariable=self.varnames, height=19)
        self.listbox.grid(row=1, column=0, columnspan=2, sticky='NSEW')
        button_frame = ttk.Frame(self.left, padding=(0, 4, 0, 10))
        ttk.Button(button_frame, style="GradientButton", image='add',
            command=self.add_var).grid(row=0, column=0, sticky='NW')
        ttk.Button(button_frame, style="GradientButton", image='remove',
            padding=(0,8), command=self.remove_var).grid(row=0, column=1, sticky='NW')
        button_frame.grid(row=2, column=0, sticky='NW')
        self.columnconfigure(1, weight=1)
        self.rowconfigure(1, weight=1)
        self.left.grid(row=1, rowspan=2, column=0, sticky='NSW', padx=10, pady=10)
        self.text = ScrolledText(self)
        self.text.frame.grid(row=1, column=1, pady=10, sticky='NSEW')
        ttk.Button(self, text='Done', command = self.done).grid(
            row=2, column=1, pady=20, padx=20, sticky='ES')
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
        self.root_window = root = tkinter.Tk()
        root.withdraw()
        os.chdir(os.environ['HOME'])
        os.makedirs(jupyter_runtime_dir, mode=0o755, exist_ok=True)
        self.icon = tkinter.Image("photo", file=self.icon_file)
        root.tk.call('wm','iconphoto', root._w, self.icon)
        self.menubar = menubar = tkinter.Menu(root)
        root.createcommand('::tk::mac::ShowPreferences', self.edit_env)
        apple_menu = tkinter.Menu(menubar, name="apple")
        apple_menu.add_command(label='About SageMath ...', command=self.about_sagemath)
        menubar.add_cascade(menu=apple_menu)
        root.config(menu=menubar)
        ttk.Label(root, text="SageMath 9.4").pack(padx=20, pady=20)

    def about_sagemath(self):
        AboutDialog(self.root_window, 'SageMath', self.about)

    def edit_env(self):
        editor = EnvironmentEditor(self.launcher)
        editor.go()

    def run(self):
        symlink = path_join(os.path.sep, 'var', 'tmp', 'sage-%s-current'%sagemath_version)
        self.launcher = LaunchWindow(root=self.root_window)
        if not os.path.islink(symlink):
            try:
                os.symlink(current, symlink)
            except Exception as e:
                showwarning(parent=self.root_window,
                            message="%s Cannot create %s; SageMath must exit."%(e, symlink))
                sys.exit(1)
        self.root_window.mainloop()
        
if __name__ == '__main__':
    SageApp().run()
