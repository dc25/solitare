## Solitaire Written in Haskell

This repository implements a version of Klondike Solitare.  Most of the code is written in Haskell with a layer of typescript that works with the DOM.  The d3.js library is used to manipulate svg images (cards) and handle evenings mouse picks and movement.

The game runs in the browser without any backend server support.

It seems to work best on Linux running Chrome - other environments still work but tend to be a little slow to respond to mouse movement.

It will not work well on touchscreen devices.

You can [try the game out here](http://dc25.github.io/solitaire)
