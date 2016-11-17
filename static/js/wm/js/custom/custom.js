function navScrollAnim()
{
    var scroll = jQuery(window)
        .scrollTop();
    // change navbar bg color on scroll
    if(scroll > 10)
    {
        if(jQuery('#main-navbar').hasClass('just-white-bg'))
        {
            jQuery('#main-navbar')
                .addClass('white-bg');
        }
        else if(jQuery('#main-navbar').hasClass('just-grey-bg'))
        {
            jQuery('#main-navbar')
                .removeClass('grey-bg');
            jQuery('#main-navbar')
                .addClass('white-bg');
            jQuery('#main-navbar')
                .addClass('nav-loaded');
        }
        else if(jQuery('#main-navbar').hasClass('type-standard-subpage'))
        {
            jQuery('#main-navbar')
                .removeClass('trans-bg');
            jQuery('#main-navbar')
                .addClass('white-bg');
            jQuery('#main-navbar')
                .addClass('nav-loaded');

        }
        else if(jQuery('#main-navbar').hasClass('transparent-menu'))
        {
            jQuery('#main-navbar')
                .removeClass('trans-bg');
            jQuery('#main-navbar')
                .addClass('white-bg');
            jQuery('#main-navbar')
                .addClass('nav-loaded');
        }
        else
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
        if(jQuery('#main-navbar').hasClass('just-white-bg'))
        {
            jQuery('#main-navbar')
                .addClass('white-bg');
        }
        else if(jQuery('#main-navbar').hasClass('just-grey-bg'))
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('grey-bg');
        }
        else if(jQuery('#main-navbar').hasClass('type-standard-subpage'))
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('trans-bg');
        }
        else if(jQuery('#main-navbar').hasClass('transparent-menu'))
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('trans-bg');
        }
        else
        {
            jQuery('#main-navbar')
                .removeClass('white-bg');
            jQuery('#main-navbar')
                .addClass('grey-bg');
        }
    }
}

jQuery(document).ready(function( $ ) {

    window.sr = new ScrollReveal();

    sr.reveal('.scroll_show', {
        // 'bottom', 'left', 'top', 'right'
        origin: 'bottom',
        // Can be any valid CSS distance, e.g. '5rem', '10%', '20vw', etc.
        distance: '0px',
        // Time in milliseconds.
        duration: 500,
        delay: 0,
        // Starting angles in degrees, will transition from these values to 0 in all axes.
        rotate: { x: 0, y: 0, z: 0 },
        // Starting opacity value, before transitioning to the computed opacity.
        opacity: 0,
        // Starting scale value, will transition from this value to 1
        scale: 0.9,
        // Accepts any valid CSS easing, e.g. 'ease', 'ease-in-out', 'linear', etc.
        easing: 'cubic-bezier(0.6, 0.2, 0.1, 1)',
        // `<html>` is the default reveal container. You can pass either:
        // DOM Node, e.g. document.querySelector('.fooContainer')
        // Selector, e.g. '.fooContainer'
        container: window.document.documentElement,
        // true/false to control reveal animations on mobile.
        mobile: true,
        // true:  reveals occur every time elements become visible
        // false: reveals occur once as elements become visible
        reset: false,
        // 'always' — delay for all reveal animations
        // 'once'   — delay only the first time reveals occur
        // 'onload' - delay only for animations triggered by first load
        useDelay: 'always',
        // Change when an element is considered in the viewport. The default value
        // of 0.20 means 20% of an element must be visible for its reveal to occur.
        viewFactor: 0.25
    },100);
    $('#tile-region .ringpage-image .tile-image-link')
        .click(function(){
            $('#tile-modal .modal-body img#modal-thumb')
                .attr('src',$(this).data('lgimg'));
        });

    $('.localscroll').localScroll({
        offset: {
            left: 0, top: -$('#main-navbar.navbar-fixed-top')
                .outerHeight()
        }
    });

    if(!jQuery('.navbar-wrapper').hasClass('type-standard-subpage') &&
        !jQuery('.navbar-wrapper').hasClass('type-standard-homepage'))
        $('.navbar-wrapper')
            .css('min-height',jQuery('#main-navbar').innerHeight());

    if(jQuery('.navbar-wrapper').hasClass('type-standard-homepage'))
        $('.navbar-wrapper')
            .css('min-height',jQuery('#main-navbar .navbar-top-banner').innerHeight());

    navScrollAnim();
    jQuery(window)
        .scroll(function(e){
            navScrollAnim();
        });
    $(window).bind('load', function() {
    });
});
