function hoverSplash(el, event) {
  var hover = ('mouseover' == event.type) ? true : false;
    (hover) ? (Element.addClassName(el, 'hover')) : (Element.removeClassName(el,'hover'));
}