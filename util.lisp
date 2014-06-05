(in-package :house)

(defun debug! (&optional (stream *standard-output*))
  (flet ((dbg (label &rest msg) (format stream ">>>> ~a~%~{~s~%----------~%~}~%" label msg)))
    (defmethod process-ready :after ((sock stream-server-usocket) conns buffers)
	       (dbg "New listener..." sock
		    "CONNECTIONS: " (alexandria:hash-table-keys conns)
		    "BUFFERS: " (alexandria:hash-table-keys buffers)))
    (defmethod process-ready :before ((sock stream-usocket) conns buffers)
	       (dbg "Preparing to buffer..." sock
		    "CONNECTIONS: " (alexandria:hash-table-keys conns)
		    "BUFFERS: " (alexandria:hash-table-keys buffers)))
    (defmethod flex-stream :before (sock)
	       (dbg "Creating flexi-stream..." sock (get-peer-address sock) (get-peer-port sock)))
    (defmethod handle-request :before (sock req) 
	       (dbg "Handling request..." sock req (resource req) (headers req) (parameters req)))
    (defmethod handle-request :after (sock req) 
	       (dbg "Completed request..."))
    (defmethod buffer! :before (buf)
	       (dbg "Buffering..." buf (tries buf)))
    (defmethod buffer! :after (buf)
	       (dbg "Buffered..."
		    (coerce (reverse (contents buf)) 'string))
	       (when (> (tries buf) +max-buffer-tries+)
		 (dbg "Needy buffer..." buf (tries buf) (coerce (reverse (contents buf)) 'string))))
    (defmethod write! :before ((res response) sock) 
	       (dbg "Writing response..."))
    (defmethod error! :before (res sock &optional instance) 
	       (dbg "Sending error response..."
		    instance sock res (response-code res)))
    (defmethod subscribe! :before (chan sock) 
	       (dbg "New subscriber" chan))
    (defmethod publish! :before (chan msg) 
	       (dbg "Publishing to channel" chan msg))
    nil))

(defmethod next-power-of-two ((num number))
  (loop for i from 1 for pow = (expt 2 i)
     when (>= pow num) return i))

(defmacro char-range ((&rest start-to-end-pairs) &key (plus) (not))
  (let ((res))
    (loop for (a to b) on start-to-end-pairs by #'cdddr
       do (let ((min (min (char-code a) (char-code b)))
		(max (max (char-code a) (char-code b))))
	    (loop for code from min to max for c = (code-char code)
	       unless (find c not) do (push c res))))
    (coerce (nreverse (append (set-difference plus not) res)) 'string)))

(defmethod ->keyword ((thing symbol))
  (intern (symbol-name thing) :keyword))

(defmethod ->keyword ((thing string))
  (intern (string-upcase thing) :keyword))

(defmethod lookup (key (hash hash-table))
  (gethash key hash))

(defmethod lookup (key (session session))
  (gethash key (session-values session)))

(defgeneric (setf lookup) (new-value key session)
  (:documentation "Setter for lookup methods"))

(defmethod (setf lookup) (new-value key (session session))
  (setf (gethash key (session-values session)) new-value))

(defmethod (setf lookup) (new-value key (hash hash-table))
  (setf (gethash key hash) new-value))

(defmethod flex-stream ((sock usocket))
  (flex:make-flexi-stream (socket-stream sock) :external-format :utf-8))

(defmethod uri-decode ((thing null)) nil)

(defmethod uri-decode ((string string))
  (coerce 
   (loop with len = (length string) and i = 0
      until (>= i len)
      for char = (aref string i) for inc-by = 1
      collect  (cond ((eql #\+ char)
		      #\space)
		     ((eql #\% char)
		      (setf inc-by 3)
		      ;;; TODO error trap here
		      (code-char (parse-integer (subseq string (+ i 1) (+ i 3)) :radix 16)))
		     (t
		      char))
      do (incf i inc-by))
   'string))

(defmethod path->uri ((path pathname) &key stem-from)
  (format nil "/~{~a/~}~a.~a"
	  (if stem-from
	      (member stem-from (cdr (pathname-directory path)) :test #'string=)
	      (cdr (pathname-directory path)))
	  (pathname-name path)
	  (pathname-type path)))

(defparameter *mimetype-table*
  '(("atom" . "application/atom+xml")
    ("bmp" . "image/bmp")
    ("cmc" . "application/vnd.cosmocaller")
    ("css" . "text/css")
    ("gif" . "image/gif")
    ("htm" . "text/html")
    ("html" . "text/html")
    ("ico" . "image/x-icon")
    ("jpe" . "image/jpeg")
    ("jpeg" . "image/jpeg")
    ("jpg" . "image/jpeg")
    ("js" . "application/javascript")
    ("json" . "application/json")
    ("mid" . "audio/midi")
    ("midi" . "audio/midi")
    ("mov" . "video/quicktime")
    ("mp3" . "audio/mpeg")
    ("mp4" . "video/mp4")
    ("mpe" . "video/mpeg")
    ("mpeg" . "video/mpeg")
    ("mpg" . "video/mpeg")
    ("oga" . "audio/ogg")
    ("ogg" . "audio/ogg")
    ("ogv" . "video/ogg")
    ("ogx" . "application/ogg")
    ("png" . "image/png")
    ("tif" . "image/tiff")
    ("tiff" . "image/tiff")
    ("wav" . "audio/x-wav")
    ("xhtml" . "application/xhtml+xml")
    ("xml" . "application/xml")))

(defmethod path->mimetype ((path pathname))
  (aif (cdr (assoc (pathname-type path) *mimetype-table* :test #'string=))
       it
       "text/plain"))
