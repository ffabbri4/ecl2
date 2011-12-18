;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: C -*-
;;;;
;;;; CMPEVAL --  The Expression Dispatcher.

;;;;  Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
;;;;  Copyright (c) 1990, Giuseppe Attardi.
;;;;
;;;;    ECoLisp is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.

(in-package "COMPILER")

(defun c1expr (form)
  (let ((*current-form* form))
  (setq form (catch *cmperr-tag*
    (cond ((symbolp form)
	   (setq form (chk-symbol-macrolet form))
	   (cond ((not (symbolp form))
		  (c1expr form))
		 ((eq form nil) (c1nil))
		 ((eq form t) (c1t))
		 ((keywordp form)
		  (make-c1form* 'LOCATION :type (object-type form)
				:args (add-symbol form)))
		 ((constantp form)
		  (or (c1constant-value (symbol-value form) :only-small-values t)
		      (c1var form)))
		 (t (c1var form))))
	  ((consp form)
	   (let ((fun (car form)))
	     (cond ((symbolp fun)
		    (c1call-symbol fun (cdr form)))
		   ((and (consp fun) (eq (car fun) 'LAMBDA))
		    (c1funcall form))
		   (t (cmperr "~s is not a legal function name." fun)))))
	  (t (c1constant-value form :always t))))))
  (if (eq form '*cmperr-tag*)
      (c1nil)
      form))

(defvar *c1nil* (make-c1form* 'LOCATION :type (object-type nil) :args nil))
(defun c1nil () *c1nil*)
(defvar *c1t* (make-c1form* 'LOCATION :type (object-type t) :args t))
(defun c1t () *c1t*)

(defun c1call-symbol (fname args &aux fd success can-inline)
  (cond ((setq fd (gethash fname *c1-dispatch-table*))
	 (funcall fd args))
	((c1call-local fname args))
	((and (setq can-inline (inline-possible fname))
	      (setq fd (compiler-macro-function fname))
	      (progn
		(multiple-value-setq (fd success)
		  (cmp-expand-compiler-macro fd fname args))
		success))
	 (c1expr fd))
	((and can-inline
	      (progn
		(multiple-value-setq (fd success)
		  (clos-compiler-macro-expand fname args))
		success))
	 (c1expr fd))
	((setq fd (cmp-macro-function fname))
	 (c1expr (cmp-expand-macro fd (list* fname args))))
	((and can-inline
	      (setf fd (si::get-sysprop fname 'inline))
	      (<=(cmp-env-optimization 'space) 1))
	 (format t "~&;;; Inlining ~a" fname)
	 (c1expr `(funcall ,fd ,@args)))
	(t (c1call-global fname args))))

(defun c1call-local (fname args)
  (let ((fun (local-function-ref fname)))
    (when fun
      (when (> (length args) si::c-arguments-limit)
	(return-from c1call-local (unoptimized-long-call `#',fname args)))
      (let* ((forms (c1args* args))
	     (lambda-form (fun-lambda fun))
	     (return-type (or (get-local-return-type fun) 'T))
	     (arg-types (get-local-arg-types fun)))
	  ;; Add type information to the arguments.
	(when arg-types
	  (let ((fl nil))
	    (dolist (form forms)
	      (cond ((endp arg-types) (push form fl))
		    (t (push (and-form-type (car arg-types) form (car args)
					    :safe "In a call to ~a" fname)
			     fl)
		       (pop arg-types)
		       (pop args))))
	    (setq forms (nreverse fl))))
	(make-c1form* 'CALL-LOCAL
                      :sp-change t ; conservative estimate
                      :side-effects t ; conservative estimate
                      :type return-type
		      :args fun forms)))))

(defun c1call-global (fname args)
#|
	  ((maybe-optimize-structure-access fname args))
	  #+clos
	  ((maybe-optimize-generic-function fname args))
|#
  ;; When the function takes many arguments, we will need a
  ;; special C form to call it. It takes extra code for
  ;; handling the stack
  (when (> (length args) si::c-arguments-limit)
    (return-from c1call-global
      (unoptimized-long-call `#',fname args)))
  (let* ((forms (c1args* args)))
    ;; If all arguments are constants, try to precompute the function
    ;; value
    (when (and (get-sysprop fname 'pure)
	       (policy-evaluate-forms)
	       (inline-possible fname))
      (loop with all-values = '()
	    with constant-p
	    with v
	    for form in forms
	    do (if (multiple-value-setq (constant-p v)
		     (c1form-constant-p form))
		   (push v all-values)
		   (return nil))
	    finally (return-from c1call-global
		      (c1constant-value (apply fname (nreverse all-values))
					:always t))))
    ;; Otherwise emit a global function call
    (make-c1form* 'CALL-GLOBAL
		  :sp-change (function-may-change-sp fname)
		  :side-effects (function-may-have-side-effects fname)
		  :type (propagate-types fname forms)
		  :args fname forms
		  ;; loc and type are filled by c2expr
		  )))

(defun c2expr (form)
  (with-c1form-env (form form)
    (let* ((name (c1form-name form))
           (args (c1form-args form))
           (dispatch (gethash name *c2-dispatch-table*)))
      (if (or (eq name 'LET) (eq name 'LET*))
          (let ((*volatile* (c1form-volatile* form)))
            (declare (special *volatile*))
            (apply dispatch args))
          (apply dispatch args)))))

(defun c2expr* (form)
  (let* ((*exit* (next-label))
	 (*unwind-exit* (cons *exit* *unwind-exit*))
	 ;;(*lex* *lex*)
	 (*lcl* *lcl*)
	 (*temp* *temp*))
    (c2expr form)
    (wt-label *exit*))
  )

(defun c1with-backend (forms)
  (c1progn (loop for tag = (pop forms)
              for form = (pop forms)
              while tag
              when (eq tag :c/c++)
              collect form)))

(defun c1progn (forms)
  (cond ((endp forms) (t1/c1expr 'NIL))
	((endp (cdr forms)) (t1/c1expr (car forms)))
	(t (let* ((fl (mapcar #'t1/c1expr forms))
		  (output-form (first (last fl)))
		  (output-type (and output-form (c1form-type output-form))))
	     (make-c1form* 'PROGN :type output-type :args fl)))))

(defun c2progn (forms)
  ;; c1progn ensures that the length of forms is not less than 1.
  (do ((l forms (cdr l))
       (lex *lex*))
      ((endp (cdr l))
       (c2expr (car l)))
    (let* ((this-form (first l))
	   (name (c1form-name this-form)))
      (let ((*destination* 'TRASH))
	(c2expr* (car l)))
      (setq *lex* lex)	; recycle lex locations
      ;; Since PROGN does not have tags, any transfer of control means
      ;; leaving the current PROGN statement.
      (when (or (eq name 'GO) (eq name 'RETURN-FROM))
	(return)))))

(defun c1args* (forms)
  (mapcar #'c1expr forms))

;;; ----------------------------------------------------------------------

(defvar *compiler-temps*
	'(tmp0 tmp1 tmp2 tmp3 tmp4 tmp5 tmp6 tmp7 tmp8 tmp9))

(defmacro sys::define-inline-function (name vars &body body)
  (let ((temps nil)
	(*compiler-temps* *compiler-temps*))
    (dolist (var vars)
      (if (and (symbolp var)
	       (not (member var '(&OPTIONAL &REST &KEY &AUX) :test #'eq)))
	(push (or (pop *compiler-temps*)
		  (gentemp "TMP" (find-package 'COMPILER)))
	      temps)
	(error "The parameter ~s for the inline function ~s is illegal."
	       var name)))
    (let ((binding (cons 'LIST (mapcar
				#'(lambda (var temp) `(list ',var ,temp))
				vars temps))))
      `(progn
	 (defun ,name ,vars ,@body)
	 (define-compiler-macro ,name ,temps (list* 'LET ,binding ',body))))))
