Prerequisites
=============

* source-highlight 3.1
* perl
  * Dancer
  * DateTime
  * Data::Uniqid
  * Inline::Python
    * pygments in your python installation
  * MongoDB
  * Template::Toolkit

Installation
============

    cpanm Dancer Dancer::Plugin::Mongo Template DateTime Data::Uniqid

    sudo aptitude install python-pygments
    or follow
    http://pygments.org/docs/installation/

Running
=======

    cp config.yml.dist config.yml
    cd bin/
    cp app.pl ../Pastedance.pl
    ./Pastedance.pl

or one of the other many ways to run a Dancer application. See
[Dancer::Deployment](http://search.cpan.org/perldoc?Dancer::Deployment) for
some hints.

Notes
=====
* You can see Pastedance in action here: <http://pb.rbfh.de/>
* An [App::Nopaste
  plugin](http://github.com/datamuc/App-Nopaste-Service-Pastedance) for
  Pastedance is also available
