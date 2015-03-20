///<reference path="d3.d.ts" />
"use strict";
// A & B are required by haste for callbacks.  See: 
// https://github.com/valderman/haste-compiler/blob/master/doc/js-externals.txt
// for details.
var A;
var B;
// For debugging.
function showAlert_ffi(msg) {
    alert(msg);
}
// Global scale to apply to all cards displayed
var cardScale = 0.5;
var drag = d3.behavior.drag().on("dragstart", dragstart).on("drag", dragmove).on("dragend", dragend);
function dragstart() {
    d3.event.sourceEvent.stopPropagation();
    // Turn off mouseover across the board while dragging
    var selectArg = 'g[class*="visible"]';
    d3.selectAll(selectArg).on("mouseover", null);
}
// Define drag beavior
function dragmove(d) {
    d.xtranslate += d3.event.dx / cardScale;
    d.ytranslate += d3.event.dy / cardScale;
    d3.select(this).attr("transform", "scale (" + cardScale + ")" + "translate (" + d.xtranslate + "," + d.ytranslate + ")");
}
// Provide for callback into haskell when object stops being dragged.
var dragEndCallback;
// Called from haskell
function setDragEndCallback_ffi(cb) {
    dragEndCallback = cb;
}
// Define dragend behavior - just call back into haskell.
function dragend(d) {
    // Turn on mouseover for all visible objects when done dragging
    var selectArg = 'g[class*="visible"]';
    d3.selectAll(selectArg).on("mouseover", mouseover);
    // additional select("g") because card is nested below dragged object
    var draggedId = d3.select(this).select("g").attr("id");
    var coordinates = d3.mouse(this.parentNode);
    var xCoord = coordinates[0];
    var yCoord = coordinates[1];
    B(A(dragEndCallback, [[0, draggedId], [0, xCoord], [0, yCoord], 0]));
}
// Provide for callback into haskell when mouse passes over object
var mouseoverCallback;
// Called from haskell
function setMouseoverCallback_ffi(cb) {
    mouseoverCallback = cb;
}
// Define mouseover behavior - just call back into haskell.
function mouseover(d, i) {
    // additional select("g") because card is nested below event object
    var draggedId = d3.select(this).select("g").attr("id");
    var coordinates = d3.mouse(this.parentNode);
    var xCoord = coordinates[0];
    var yCoord = coordinates[1];
    B(A(mouseoverCallback, [[0, draggedId], [0, xCoord], [0, yCoord], 0]));
}
function getBaseOffset(card) {
    // queryString thanks to : http://stackoverflow.com/questions/23034283/is-it-possible-to-use-htmls-queryselector-to-select-by-xlink-attribute-in-an
    var queryString = 'use[*|href="#base"]';
    var base = d3.select(card).select(queryString);
    var xOffset = parseInt(base.attr("x"));
    var yOffset = parseInt(base.attr("y"));
    return { x: xOffset, y: yOffset };
}
function alignCard_ffi(name, classname, x, y) {
    var card = document.getElementById(name);
    var baseOffset = getBaseOffset(card);
    d3.select('body svg g[data-name="' + name + '"]').data([{ xtranslate: (0 + x / cardScale - baseOffset.x), ytranslate: (235.27 + y / cardScale - baseOffset.y) }]).attr("class", function (d, i) {
        return classname;
    }).transition().attr("transform", function (d, i) {
        return "scale (" + cardScale + ")" + "translate (" + d.xtranslate + "," + d.ytranslate + ")";
    });
}
function placeCard_ffi(name, classname, x, y) {
    var card = document.getElementById(name);
    var baseOffset = getBaseOffset(card);
    d3.select("body svg").append("g").each(function (d, i) {
        this.appendChild(card.cloneNode(true));
    }).attr("data-name", function (d, i) {
        return name;
    }).attr("class", function (d, i) {
        return classname;
    }).data([{ xtranslate: (0 + x / cardScale - baseOffset.x), ytranslate: (235.27 + y / cardScale - baseOffset.y) }]).attr("transform", function (d, i) {
        return "scale (" + cardScale + ")" + "translate (" + d.xtranslate + "," + d.ytranslate + ")";
    }).on("mouseover", mouseover);
    // There must be a better way of enabling drag 
    // for new cards in a visble column.
    if (classname.indexOf("visibleColumn") > -1) {
        var selectArg = "g[class=" + classname + "]";
        d3.select(selectArg).call(drag);
    }
}
function deleteBySelectionString_ffi(cssSelection) {
    d3.selectAll(cssSelection).remove();
}
function loadCards_ffi(cb) {
    //Import the full deck of cards.
    d3.xml("pretty-svg-cards.svg", "image/svg+xml", function (xml) {
        d3.select("body").append("div").attr("style", "display: none; visibility: hidden").each(function (d, i) {
            this.appendChild(xml.documentElement.cloneNode(true));
        });
        // Call back to haskell when done.
        B(A(cb, [0]));
    });
}