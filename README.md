Prerequisites
=============

* source-highlight 3.1
* Berkley-DB
* perl
  * Dancer
  * KiokuDB
  * perl bindings for source-highlight:  
    https://code.launchpad.net/~chust/+junk/SourceHighlight
  * Template::Toolkit

Installation
============

    cpan Dancer KiokuDB::Backend::BDB Template

Running
=======

    ./Pastedance.pl

Notes
=====
* You can see Pastedance in action here: <http://pb.rbfh.de/>
* An [App::Nopaste plugin](http://github.com/datamuc/App-Nopaste-Service-Pastedance) for Pastedance is also available
