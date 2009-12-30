;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: C -*-
;;;;
;;;;  Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
;;;;  Copyright (c) 1990, Giuseppe Attardi.
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.
;;;;
;;;;  CMPVARS -- Global variables and flag definitions
;;;;

(in-package "C-DATA")

;;;
;;; VARIABLES
;;;

;;; --cmpinline.lsp--
;;;
;;; Empty info struct
;;;
(defvar *inline-functions* nil)
(defvar *inline-blocks* 0)
;;; *inline-functions* holds:
;;;	(...( function-name . inline-info )...)
;;;
;;; *inline-blocks* holds the number of C blocks opened for declaring
;;; temporaries for intermediate results of the evaluation of inlined
;;; function calls.

;;; --cmputil.lsp--
;;;
;;; Variables and constants for error handling
;;;
(defvar *current-toplevel-form* '|compiler preprocess|)
(defvar *current-form* '|compiler preprocess|)
(defvar *current-c2form* nil)
(defvar *compile-file-position* -1)
(defvar *first-error* t)
(defconstant *cmperr-tag* (cons nil nil))

(defvar *active-handlers* nil)
(defvar *active-protection* nil)
(defvar *pending-actions* nil)

(defvar *compiler-conditions* '()
  "This variable determines whether conditions are printed or just accumulated.")

(defvar *compile-print* nil
  "This variable controls whether the compiler displays messages about
each form it processes. The default value is NIL.")

(defvar *compile-verbose* nil
  "This variable controls whether the compiler should display messages about its
progress. The default value is T.")

(defvar *suppress-compiler-messages* nil
  "A type denoting which compiler messages and conditions are _not_ displayed.")

(defvar *suppress-compiler-notes* nil) ; Deprecated
(defvar *suppress-compiler-warnings* nil) ; Deprecated

(defvar *compiler-break-enable* nil)

(defvar *compiler-in-use* nil)
(defvar *compiler-input*)
(defvar *compiler-output1*)
(defvar *compiler-output2*)
(defvar *dump-output*)

;;; --cmpcbk.lsp--
;;;
;;; List of callbacks to be generated
;;;
(defvar *callbacks* nil)

;;; --cmpcall.lsp--
;;;
;;; Whether to use linking calls.
;;;
(defvar *compile-to-linking-call* t)
(defvar *compiler-declared-globals*)

;;; --cmpenv.lsp--
;;;
;;; These default settings are equivalent to (optimize (speed 3) (space 0) (safety 2))
;;;
(defvar *safety* 2)
(defvar *speed* 3)
(defvar *space* 0)
(defvar *debug* 0)

;;; Emit automatic CHECK-TYPE forms for function arguments in lambda forms.
(defvar *automatic-check-type-in-lambda* t)

;;;
;;; Compiled code uses the following kinds of variables:
;;; 1. Vi, declared explicitely, either unboxed or not (*lcl*, next-lcl)
;;; 2. Ti, declared collectively, of type object, may be reused (*temp*, next-temp)
;;; 4. lexi[j], for lexical variables in local functions
;;; 5. CLVi, for lexical variables in closures

(defvar *lcl* 0)		; number of local variables

(defvar *level* 0)		; nesting level for local functions

(defvar *lex* 0)		; number of lexical variables in local functions
(defvar *max-lex* 0)		; maximum *lex* reached

(defvar *env* 0)		; number of variables in current form
(defvar *max-env* 0)		; maximum *env* in whole function
(defvar *env-lvl* 0)		; number of levels of environments

(defvar *next-cfun* 0)		; holds the last cfun used.

;;;
;;; *tail-recursion-info* holds NIL, if tail recursion is impossible.
;;; If possible, *tail-recursion-info* holds
;;	( c1-lambda-form  required-arg .... required-arg ),
;;; where each required-arg is a var-object.
;;;
(defvar *tail-recursion-info* nil)

(defvar *allow-c-local-declaration* t)
(defvar *notinline* nil)

;;; --cmpexit.lsp--
;;;
;;; *last-label* holds the label# of the last used label.
;;; *exit* holds an 'exit', which is
;;	( label# . ref-flag ) or one of RETURNs (i.e. RETURN, RETURN-FIXNUM,
;;	RETURN-CHARACTER, RETURN-DOUBLE-FLOAT, RETURN-SINGLE-FLOAT, or
;;	RETURN-OBJECT).
;;; *unwind-exit* holds a list consisting of:
;;	( label# . ref-flag ), one of RETURNs, TAIL-RECURSION-MARK, FRAME,
;;	JUMP, BDS-BIND (each pushed for a single special binding), or a
;;	LCL (which holds the bind stack pointer used to unbind).
;;;
(defvar *last-label* 0)
(defvar *exit*)
(defvar *unwind-exit*)

(defvar *current-function* nil)

(defvar *cmp-env* (cons nil nil)
"The compiler environment consists of a pair or cons of two
lists, one containing variable records, the other one macro and
function recors:

variable-record = (:block block-name) |
                  (:tag ({tag-name}*)) |
                  (:function function-name) |
                  (var-name {:special | nil} bound-p) |
                  (symbol si::symbol-macro macro-function) |
                  CB | LB | UNWIND-PROTECT
macro-record =	(function-name function) |
                (macro-name si::macro macro-function)
                CB | LB | UNWIND-PROTECT

A *-NAME is a symbol. A TAG-ID is either a symbol or a number. A
MACRO-FUNCTION is a function that provides us with the expansion
for that local macro or symbol macro. BOUND-P is true when the
variable has been bound by an enclosing form, while it is NIL if
the variable-record corresponds just to a special declaration.
CB, LB and UNWIND-PROTECT are only used by the C compiler and
they denote closure, lexical environment and unwind-protect
boundaries. Note that compared with the bytecodes compiler, these
records contain an additional variable, block, tag or function
object at the end.")

;;; --cmplog.lsp--
;;;
;;; Destination of output of different forms. See cmploc.lsp for types
;;; of destinations.
;;;
(defvar *destination*)

;;; --cmpmain.lsp--
;;;
;;; Do we debug the compiler? Then we need files not to be deleted.

(defvar *debug-compiler* nil)
(defvar *delete-files* t)
(defvar *files-to-be-deleted* '())

;;; --cmptop.lsp--
;;;
(defvar *do-type-propagation* nil
  "Flag for switching on the type propagation phase. Use with care, experimental.")

(defvar *compiler-phase* nil)

(defvar *volatile*)

(defvar *compile-toplevel* T
  "Holds NIL or T depending on whether we are compiling a toplevel form.")
(defvar *compile-time-too* nil)

(defvar *clines-string-list* '()
  "List of strings containing C/C++ statements which are directly inserted
in the translated C/C++ file. Notice that it is unspecified where these
lines are inserted, but the order is preserved")

(defvar *permanent-data* nil)		; detemines whether we use *permanent-objects*
					; or *temporary-objects*
(defvar *permanent-objects* nil)	; holds { ( object (VV vv-index) ) }*
(defvar *temporary-objects* nil)	; holds { ( object (VV vv-index) ) }*
(defvar *load-objects* nil)		; hash with association object -> vv-location
(defvar *load-time-values* nil)		; holds { ( vv-index form ) }*,
;;;  where each vv-index should be given an object before
;;;  defining the current function during loading process.

(defvar *use-static-constants-p* nil)   ; T/NIL flag to determine whether one may
                                        ; generate lisp constant values as C structs

(defvar *compiler-constants* nil)	; a vector with all constants
					; only used in COMPILE

(defvar *proclaim-fixed-args* nil)	; proclaim automatically functions
					; with fixed number of arguments.
					; watch out for multiple values.

(defvar *global-var-objects* nil)	; var objects for global/special vars
(defvar *global-vars* nil)		; variables declared special
(defvar *global-funs* nil)		; holds	{ fun }*
(defvar *global-cfuns-array* nil)	; holds	{ fun }*
(defvar *linking-calls* nil)		; holds { ( global-fun-name fun symbol c-fun-name var-name ) }*
(defvar *local-funs* nil)		; holds { fun }*
(defvar *top-level-forms* nil)		; holds { top-level-form }*
(defvar *make-forms* nil)		; holds { top-level-form }*
(defvar +init-function-name+ (gensym "ENTRY-POINT"))

;;;
;;;     top-level-form:
;;;	  ( 'DEFUN'     fun-name cfun lambda-expr doc-vv sp )
;;;	| ( 'DEFMACRO'  macro-name cfun lambda-expr doc-vv sp )
;;;	| ( 'ORDINARY'  expr )
;;;	| ( 'DECLARE'   var-name-vv )
;;;	| ( 'DEFVAR'	var-name-vv expr doc-vv )
;;;	| ( 'CLINES'	string* )
;;;	| ( 'LOAD-TIME-VALUE' vv )

(defvar *reservation-cmacro* nil)

;;; *reservations* holds (... ( cmacro . value ) ...).
;;; *reservation-cmacro* holds the cmacro current used as vs reservation.

(defvar *self-destructing-fasl* '()
"A value T means that, when a FASL module is being unloaded (for
instance during garbage collection), the associated file will be
deleted. We need this for #'COMPILE because windows DLLs cannot
be deleted if they have been opened with LoadLibrary.")

(defvar *undefined-vars* nil)

;;; Only these flags are set by the user.
;;; If (safe-compile) is ON, some kind of run-time checks are not
;;; included in the compiled code.  The default value is OFF.

(defconstant +init-env-form+
  '((*gensym-counter* 0)
    (*compiler-in-use* t)
    (*compiler-phase* 't1)
    (*callbacks* nil)
    (*next-cfun* 0)
    (*lcl* 0)
    (*last-label* 0)
    (*load-objects* (make-hash-table :size 128 :test #'equal))
    (*make-forms* nil)
    (*static-constants* nil)
    (*permanent-objects* nil)
    (*temporary-objects* nil)
    (*local-funs* nil)
    (*global-var-objects* nil)
    (*global-vars* nil)
    (*global-funs* nil)
    (*global-cfuns-array* nil)
    (*linking-calls* nil)
    (*global-entries* nil)
    (*undefined-vars* nil)
    (*top-level-forms* nil)
    (*clines-string-list* '())
    (*inline-functions* nil)
    (*inline-blocks* 0)
    (*debugger-hook* 'compiler-debugger)
    (*type-and-cache* (type-and-empty-cache))
    (*type-or-cache* (type-or-empty-cache))
    (*values-type-or-cache* (values-type-or-empty-cache))
    (*values-type-and-cache* (values-type-and-empty-cache))
    (*values-type-primary-type-cache* (values-type-primary-type-empty-cache))
    (*values-type-to-n-types-cache* (values-type-to-n-types-empty-cache))
    ))
