  {$IF Defined(MSWINDOWS)}
  Winapi.OpenGL,
  Winapi.OpenGLExt,
  {$ELSEIF Defined(IOS)}
  iOSapi.OpenGLES,
  {$ELSEIF Defined(ANDROID)}
  Androidapi.Gles2,
  {$ELSEIF Defined(MACOS)}
  Macapi.CocoaTypes,
  Macapi.OpenGL,
  {$ELSE}
    {$MESSAGE Error 'Unsupported platform'}
  {$ENDIF}