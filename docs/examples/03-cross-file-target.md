# Cross-file target

This file is the landing page for the cross-file link tests in
[03-cross-file-links.md](03-cross-file-links.md). If you arrived
here by tapping a link in that file, the feature works end to end.

## Introduction

The viewer treats this page like any other `.md` document — same
rendering pipeline, same reading-comfort controls, same TOC drawer.

Back to the [origin](03-cross-file-links.md) when you're done.

## A specific heading

This heading has the slug `a-specific-heading`. The origin file
contains a cross-file-plus-anchor link that points here:

> `[go to the heading inside the sibling](03-cross-file-target.md#a-specific-heading)`

If you tapped that link, you should have landed exactly on this
heading, not the top of the file.

## Another section

A second heading so the page is tall enough for the cross-file
anchor jump to be visibly different from "opened at the top".

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua.
Enim ad minim veniam, quis nostrud exercitation ullamco laboris
nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
cupidatat non proident, sunt in culpa qui officia deserunt mollit
anim id est laborum.

## Jumping around this file

- [Back to the introduction](#introduction)
- [Back to the specific heading](#a-specific-heading)
- [Back to the origin file](03-cross-file-links.md)
