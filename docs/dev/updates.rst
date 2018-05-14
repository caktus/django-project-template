Project Template Updates
========================

These are notes related to recent changes to our Django project template. Please read to be aware of
these changes and how it may impact your project either now or in the future.

Motivation for the Changes
--------------------------

A new Salt version 2015.5 was released with some deprecations as well as backwards incompatible
changes. The project template has also been slow to adapt to changes needed for Ubuntu 14.04. Recent
deployment failures also pointed to a need for more control and stability around the versions of
Salt and the related states used to provision our servers.

What Changed
------------

Provisioning and deployment assumptions have been removed from the project template.