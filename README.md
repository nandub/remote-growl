```
NOTE: On Growl 1.3.x the GrowlHelperApp binary was changed to Growl.  
The current Mac::Growl 0.67 from CPAN won't work.  I created a 
github repo (https://github.com/nandub/mac-growl-perl) 
from Mac-Growl-0.67.tar.gz to make it work with Growl 1.3.x.
```

There are a number of solutions for generating Growl notifications from Irssi,
including ones that let you do it remotely.  However none did quite what I 
wanted, so I decided to write my own.  This version uses TCP to send 
notifications so it's easy to tunnel it over SSH connections.  It also 
has an option to encrypt data using Blowfish encryption so that if you're 
not tunneling via SSH you can ensure any text sent is still encrypted.  
Lastly, this includes both an Irssi script and a command line utility that 
can be used to send Growl notifications from other scripts/programs as well.

INSTALLATION

On the Mac that you run Growl, make sure the following perl modules are
installed:

```
Mac::Growl
Crypt::CBCeasy
Crypt::Blowfish
MIME::Base64
Digest::MD5
```

Mac::Growl can be found on CPAN and also in the Growl SDK which can be
downloaded from http://growl.info.  All the other modules can be downloaded
directly from CPAN using the following command:

```
$ sudo cpan Crypt::CBCeasy
```

Copy the file .growl-server to your home directory and edit it as appropriate.
There are comments in the file that describe each parameter.  At the very least
you should change the passphrase and blowfish_key values.  Also make sure
the paths in all the image definitions are correct.

If you intend to use an ssh tunnel then leave the host set to localhost,
otherwise you should set it to the hostname or IP address of your Mac.

* Growl Server Installer

```
bash < <(curl -s https://raw.github.com/nandub/remote-growl/master/binscripts/growl-server-installer)
cd ~/growl-server
vi .growl-server 
```

Launch growl-server.pl in the background.  You can optionally invoke it
with --debug to have it output everything it receives to the console:

```
./growl-server.pl --debug &
```

Whatever hosts you plan to run growl.pl and/or send-growl.pl will also need
the perl modules mentioned above except for Mac::Growl.

If you are using Irssi then copy growl.pl to the system you are running
Irssi on.  Install growl.pl in ~/.irssi/scripts and optionally add
a symlink in ~/.irssi/scripts/autorun to load it when Irssi starts.
Edit growl.pl and scroll down to where it says "Edit the following as 
necessary". Change the host, port, passphrase, and blowfish_key parameters 
to all match those you set in ~/.growl-server on your Mac.  Then load the 
script in Irssi (/script load growl).

* Irssi Script Installer

```
bash < <(curl -s https://raw.github.com/nandub/remote-growl/master/binscripts/irssi-script-installer)
```

If you plan on using SSH port forwarding then make sure you ssh into your
Irssi system as follows:

```
$ ssh -R 7106:localhost:7106 <username>@<hostname>
```

Once you've done this, launch Irssi, load the script, and try sending
yourself a private message.  You should see it show up in Growl.

The send-growl.pl script can be used both to test the above and to send
Growl notifications from other hosts/applications as well.  Simply copy
.send-growl and send-growl.pl to the remote host, edit .send-growl as
needed, and invoke send-growl.pl.  Use --help or -? for help with using
the send-growl.pl script.

* Send Growl Installer 

```
bash < <(curl -s https://raw.github.com/nandub/remote-growl/master/binscripts/send-growl-installer)
cd ~/send-growl
vi .send-growl
```

NOTE: If you are using ssh tunnels with port forwarding then blowfish 
encryption is not necessary.  Simply comment out the blowfish_key
parameter in all the configuration files and in growl.pl and it won't 
be used.  If you are not using SSH tunnels and you use the Mac built-in
firewall (which you should) then you will need to poke a hole in the 
firewall to allow access to growl-server.pl.  To do this, invoke the
following command, changing the source IP and destination port as 
necessary:

```
$ sudo /sbin/ipfw -f add allow tcp from 1.2.3.4 to any 7106 keep-state

NOTE: you will need to invoke this each time you reboot your Mac.
```

```
USAGE

Once the growl module is loaded into Irssi the following commands can be
used:

/set growl_show_privmsg (on|off)
     Sets whether private messages trigger a Growl

/set growl_show_hilight (on|off)
     Sets whether your nickname triggers a Growl

/set growl_show_notify (on|off)
     Sets whether joins/leaves trigger a Growl

/set growl_sticky (on|off)
     Sets whether Growl popups are "sticky" and remain until you click
     on them or if they disappear on their own based on your Growl settings.

/growl watch string
     Specifies an arbitrary string that will trigger a Growl.  Useful if
     you want to be notified when specific words/phrases are mentioned.

/growl unwatch string
     Stops watching for arbitrary strings

/growl list
     Lists all strings that have been defined for watching

/growl
     With no parameters, /growl will display a help summary

/set growl_watch (on|off)
     Turns the above watch/unwatch settings on or off.  Does not affect 
     the list of items being watched.

NOTES: /growl watch uses case insensitive matching, so the command 
       "/growl watch foo" will display a Growl popup if the string Foo,
       foo, fOo, etc. appears in a message.

       A watch string can be any length and contain any characters 
       except commas.  Matching is performed by a simple perl expression,
       so characters normally used in regular expressions like * $ ( ) etc.
       may result in odd behavior unless properly escaped.

       Watch strings are saved when the script is unloaded, so any 
       watch strings you specified will be rememberd if Irssi is restarted.
```
