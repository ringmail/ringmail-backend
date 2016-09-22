# Wiremedia notes:

## Structure

  To avoid any conflicts with existing and new layouts/comps
  we are separating and preserving pre-wiremedia work. At
  the moment pages that have the page varible set to the strings
  "home" or "subpage-jumbo" or if they do not have the page varible set to
  "ringmail_2016_1" will use the old ringmail styles, footer and navigation.

  Pages/templates defining the page variable with the new "ringmail_2016_1" string
  will use the new header template, footer template and styles.

  Following existing structure, page variable should be set in template page files.

  Until launch we are placing new "example" comps coded in the /template/examples/ folder.

## Styles & JS:

  For templates with its page variable set to the new "ringmail_2016_1" strings,
  styles can be found in /static/css/wm/css/,
  we are using a less compiler to compile all of the styles found in the /static/css/wm/less.

  For Pages using the new "ringmail_2016_1" styles, we are no longer using any of the styles that
  are outside the /static/css/wm/ folder and have opted for a fresh un-modified un-customized
  version of bootstrap found in: /static/js/wm/bower_components/ . We are using bower to manage
  external library dependencies. All new javascript can be found in /static/js/wm/js/, we are using
  grunt and the grunt concat module to minify javascript.
