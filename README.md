# ediarum.WEB

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3958831.svg)](https://doi.org/10.5281/zenodo.3958831)

© 2020 by Berlin-Brandenburg Academey of Sciences and Humanities

Developed by TELOTA, a DH working group of the Berlin-Brandenburg Academey of Sciences and Humanities  
http://www.bbaw.de/telota  
telota@bbaw.de

For more infomation about **ediarum** see www.ediarum.org.

Lead Developer:

* Martin Fechner

Thanks to: 

* Theodor Costea for development support

## What does it do?

ediarum.WEB is an library for eXist-db (http://www.exist-db.org). It is tested with eXist-db versions 3.2.0, 4.6.1, and 5.2.0. 
With the help of ediarum.WEB, developers can build an entire website or just a backend used for XML based digital editions. The different functions of the library support routing, api generation, and frontend templating.

## Documentation

An introduction how to use ediarum.WEB is available at https://www.ediarum.org/docs/ediarum-web-step-for-step.

For the structure of the `appconf.xml` see [APPCONF.md](APPCONF.md).

For the definition of the API calls see [API.md](API.md).

## Development

To build a new xar package use Apache ANT (https://ant.apache.org/):

`ant build-xar`

## License

ediarum.WEB is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

ediarum.WEB is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU General Public License
along with ediarum.WEB.  If not, see <http://www.gnu.org/licenses/>.

## Third party licences

ediarum.WEB includes software from third parties, which are licensed seperately. 

### Bootstrap v4.1.3 (https://getbootstrap.com/)

Copyright 2011-2018 The Bootstrap Authors  
Copyright 2011-2018 Twitter, Inc.

* Licensed under MIT (https://github.com/twbs/bootstrap/blob/master/LICENSE)

### Font Awesome 4.6.3 

Font Awesome 4.6.3 by @davegandy - http://fontawesome.io - @fontawesome

* General License (http://fontawesome.io/license) 
* Font: SIL OFL 1.1 (https://scripts.sil.org/OFL)
* CSS: MIT License (https://opensource.org/licenses/MIT)

### jQuery v1.11.3 

(c) 2005, 2015 jQuery Foundation, Inc. 

* jquery.org/license
