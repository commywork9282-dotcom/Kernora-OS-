# Package policy

Every changed binary package must have a corresponding source package in
`packages/native/` or `packages/derived/`.

Versioning, until a final vendor suffix is chosen, is blocked. Stage 1 must
define a suffix that sorts newer than its Debian base version without claiming
to be an official Debian build.

Do not fork packages without a concrete reason. Unchanged packages remain
authenticated, pinned Debian inputs; changed packages carry a patch history,
copyright information and an entry in the distribution changelog.

