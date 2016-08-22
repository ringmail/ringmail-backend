function navScrollAnim()
{
    var scroll = jQuery(window)
        .scrollTop();
    if(scroll > 10)
    {
        if(jQuery('#main-navbar').hasClass('type-standard-subpage'))
        {
            jQuery('#main-navbar')
                .removeClass('trans-bg');
            jQuery('#main-navbar')
                .addClass('white-bg');
            jQuery('#main-navbar')
                .addClass('nav-loaded');

        }else
        {
            jQuery('#main-navbar')
                .removeClass('grey-bg');
            jQuery('#main-navbar')
                .addClass('white-bg');
            jQuery('#main-navbar')
                .addClass('nav-loaded');
        }
    }
    if(scroll < 10 && jQuery('#main-navbar').hasClass('nav-loaded'))
    {
        if(jQuery('#main-navbar').hasClass('type-standard-subpage'))
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('trans-bg');
        }else
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('grey-bg');
        }
    }
}

jQuery(document).ready(function( $ ) {

    $('.localscroll').localScroll({
        offset: {
            left: 0, top: -$('#main-navbar.navbar-fixed-top')
                .outerHeight()
        }
    });

    if(!jQuery('.navbar-wrapper').hasClass('type-standard-subpage'))
        $('.navbar-wrapper')
            .css('min-height',jQuery('#main-navbar').innerHeight());
    navScrollAnim();
    jQuery(window)
        .scroll(function(e){
            navScrollAnim();
        });
    $(window).bind('load', function() {
    });
});
