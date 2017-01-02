unit Sample.Platform.iOS;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.TypInfo,
  Macapi.ObjectiveC,
  iOSapi.UIKit,
  iOSapi.Foundation,
  iOSapi.QuartzCore,
  iOSapi.CoreGraphics,
  iOSapi.OpenGLES,
  Sample.Platform;

type
  id = Pointer;
  SEL = Pointer;

type
  { We create our own view derived from UIView. It uses an OpenGLES layer for
    rendering. Also, it intercepts certain view events. }
  IGLView = interface(UIView)
  ['{87AA45F0-2EA1-490B-8517-4BEA610E562A}']
    { From UIView }

    { Is called when the dimensions of the view have changed, usually as the
      result of rotating the device. We use this to update the size of the
      render surface accordingly. }
    procedure layoutSubviews; cdecl;

    { Is called when the user starts touching the screen. We do not support
      multi-touch in the sample apps. Instead, the first touch is converted to
      a mouse-move event and a left-mouse-button-pressed event. }
    procedure touchesBegan(touches: NSSet; withEvent: UIEvent); cdecl;

    { Is called when the user cancelled a screen touch.
      Is converted to a left-mouse-button-released event. }
    procedure touchesCancelled(touches: NSSet; withEvent: UIEvent); cdecl;

    { Is called when the user finished touching the screen.
      Is converted to a left-mouse-button-released event. }
    procedure touchesEnded(touches: NSSet; withEvent: UIEvent); cdecl;

    { Is called when the user moved one or more fingers on the screen.
      Is converted to a mouse-move event. }
    procedure touchesMoved(touches: NSSet; withEvent: UIEvent); cdecl;

    { New }

    { Is called by the display link when the screen needs to be updated. }
    procedure RenderFrame(Sender: Pointer); cdecl;
  end;

type
  { Implementation of IGLView }
  TGLView = class(TOCLocal)
  {$REGION 'Internal Declarations'}
  private
    FDisplayLink: CADisplayLink;
    FContext: EAGLContext;
    FFramebuffer: GLuint;
    FColorRenderbuffer: GLuint;
    FDepthRenderbuffer: GLuint;
    FWidth: GLint;
    FHeight: GLint;
    FSizeChanged: Boolean;
  private
    function GetNativeView: UIView; inline;
  private
    class function LayerClass(Self: Pointer; Cmd: SEL): Pointer; cdecl; static;
  public
    class procedure Setup; static;
  private
    procedure CreateContext;
    procedure CreateBuffers;
  {$ENDREGION 'Internal Declarations'}
  public
    { UIView }
    procedure layoutSubviews; cdecl;
    procedure touchesBegan(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesCancelled(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesEnded(touches: NSSet; withEvent: UIEvent); cdecl;
    procedure touchesMoved(touches: NSSet; withEvent: UIEvent); cdecl;
  public
    { IGLView }
    procedure RenderFrame(Sender: Pointer); cdecl;
  public
    { Creates the view and OpenGL context }
    constructor Create(const ABounds: CGRect);
    destructor Destroy; override;

    { Starts the render loop for the view. Creates a display link that will call
      the RenderFrame method at the refresh rate of the device. }
    procedure Start;

    { Stops the render loop. Destroys the display link. }
    procedure Stop;

    { To let Delphi know this class implements IGLView }
    function GetObjectiveCClass: PTypeInfo; override;

    { The parent Objective-C UIView class }
    property NativeView: UIView read GetNativeView;
  end;

type
  { We create our own view controller derived from UIViewController. We use it
    to control some settings for our application (main view) }
  IGLViewController = interface(UIViewController)
  ['{A632D30F-FC6A-431A-B5EC-4A3CDE6142B4}']
    { From UIViewController }

    { Is called when iOS wants to know if it should display a status bar.
      We return True to hide the status bar. }
    function prefersStatusBarHidden: Boolean; cdecl;

    { Is called when iOS wants to know if the view should be rotated when the
      user rotates the device. We return True to support rotation. }
    function shouldAutorotate: Boolean; cdecl;
  end;

type
  { Implementation of IGLViewController }
  TGLViewController = class(TOCLocal)
  {$REGION 'Internal Declarations'}
  private
    function GetNativeViewController: UIViewController; inline;
  {$ENDREGION 'Internal Declarations'}
  public
    { UIViewController }
    function prefersStatusBarHidden: Boolean; cdecl;
    function shouldAutorotate: Boolean; cdecl;
  public
    { To let Delphi know this class implementss IGLViewController }
    function GetObjectiveCClass: PTypeInfo; override;

    { The parent Objective-C UIViewController class }
    property NativeViewController: UIViewController read GetNativeViewController;
  end;

type
  { Implements the iOS UIApplicationDelegate protocol to get notified of
    certain application events. Note that unlike the previous classes, this
    class does not derive from TOCLocal. Instead, we use the Objective-C runtime
    to manually define the class (see Setup). }
  TAppDelegate = class sealed
  {$REGION 'Internal Declarations'}
  private class var
    FWindow: UIWindow;
    FView: TGLView;
    FViewController: TGLViewController;
  public const
    DelegateName = 'AppDelegate';
  private
    { Is called when the application has booted up. This is our main entry
      point. We create the main window (UIWindow), view (IGLView) and view
      controller (IGLViewController) here. }
    class function applicationDidFinishLaunchingWithOptions(self: id; _cmd: SEL;
      application: PUIApplication; options: PNSDictionary): Boolean; cdecl; static;

    { Is called when the application has completely entered the background. }
    class procedure applicationDidEnterBackground(self: id; _cmd: SEL;
      application: PUIApplication); cdecl; static;

    { Is called when the application first activated or resumes from the
      background. We kick of the render loop here by calling TGLView.Start. }
    class procedure applicationDidBecomeActive(self: id; _cmd: SEL;
      application: PUIApplication); cdecl; static;

    { Is called when the application is about to resume from the background. }
    class procedure applicationWillEnterForeground(self: id; _cmd: SEL;
      application: PUIApplication); cdecl; static;

    { Is called when the application is about to be terminated.
      We stop the render loop here by calling TGLView.Stop }
    class procedure applicationWillTerminate(self: id; _cmd: SEL;
      application: PUIApplication); cdecl; static;

    { Is called when the application is about to enter the background.
      We stop the render loop here by calling TGLView.Stop }
    class procedure applicationWillResignActive(self: id; _cmd: SEL;
      application: PUIApplication); cdecl; static;
  {$ENDREGION 'Internal Declarations'}
  public
    { Uses the Objective-C runtime to register a class that implements
      UIApplicationDelegate. }
    class procedure Setup; static;

    { Disposes of the window, view and view controller }
    class procedure Shutdown; static;
  end;

type
  { Implements iOS-specific functionality. }
  TPlatformIOS = class(TPlatformBase)
  {$REGION 'Internal Declarations'}
  private
    class procedure RunLoop; static;
  {$ENDREGION 'Internal Declarations'}
  protected
    class procedure DoRun; override;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.UITypes,
  Macapi.Helpers,
  Macapi.ObjCRuntime,
  Sample.Classes;

{$WARN SYMBOL_PLATFORM OFF}

{ This should be in Macapi.ObjCRuntime }
function objc_getMetaClass(const name: MarshaledAString): Pointer; cdecl;
  external libobjc name _PU + 'objc_getMetaClass';

{ This should be in iOSapi.QuartzCore }
type
  TCAEAGLLayer = class (TOCGenericImport<CAEAGLLayerClass, CAEAGLLayer>) end;

{ TPlatformIOS }

class procedure TPlatformIOS.DoRun;
begin
  TGLView.Setup;
  TAppDelegate.Setup;
  RunLoop;
  App.Shutdown;
  TAppDelegate.Shutdown;
end;

class procedure TPlatformIOS.RunLoop;
var
  Pool: NSAutoreleasePool;
begin
  { This is the main entry point of the application.
    On iOS, an app is started by calling UIApplicationMain, passing the name
    of the application delegate class to create (TAppDelegate.DelegateName).
    So UIApplicationMain will eventually call
    TAppDelegate.applicationDidFinishLaunchingWithOptions, which in turn will
    kick of the rest. }
  StartClock;
  Pool := TNSAutoreleasePool.Create;
  try
    UIApplicationMain(ArgCount, ArgValues, nil, StringToID(TAppDelegate.DelegateName));
  finally
    Pool.release;
  end;
end;

{ TGLView }

constructor TGLView.Create(const ABounds: CGRect);
var
  V: Pointer;
  View: UIView;
  Screen: UIScreen;
  EAGLLayer: CAEAGLLayer;
begin
  inherited Create;

  { Call the "inherited" constructor of UIView }
  View := NativeView;
  V := View.initWithFrame(ABounds);
  if (GetObjectID <> V) then
    UpdateObjectID(V);

  { On iOS8 and later we use the native scale of the screen as our content scale
    factor. This allows us to render to the exact pixel resolution of the screen
    which avoids additional scaling and GPU rendering work.
    For example the iPhone 6 Plus appears to UIKit as a 736 x 414 pt screen with
    a 3x scale factor (2208 x 1242 virtual pixels). But the native pixel
    dimensions are actually 1920 x 1080. Since we are streaming 1080p buffers
    from the camera we can render to the iPhone 6 Plus screen at 1:1 with no
    additional scaling if we set everything up correctly. Using the native scale
    of the screen also allows us to render at full quality when using the
    display zoom feature on iPhone 6/6 Plus. }
  Screen := TUIScreen.Wrap(TUIScreen.OCClass.mainScreen);
  if (TOSVersion.Check(8)) then
    TPlatformIOS.ScreenScale := Screen.nativeScale
  else
    TPlatformIOS.ScreenScale := Screen.scale;
  View.setContentScaleFactor(TPlatformIOS.ScreenScale);

  { Make view layer opaque }
  EAGLLayer := TCAEAGLLayer.Wrap((View.layer as ILocalObject).GetObjectID);
  EAGLLayer.setOpaque(True);

  { Create OpenGL context, framebuffer and renderbuffer }
  CreateContext;
  CreateBuffers;
  TPlatformIOS.App.Initialize;
  FSizeChanged := True;
end;

procedure TGLView.CreateBuffers;
begin
  glDisable(GL_DEPTH_TEST);

  glGenFramebuffers(1, @FFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, FFramebuffer);
  glErrorCheck;

  glGenRenderbuffers(1, @FColorRenderbuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, FColorRenderbuffer);
  glErrorCheck;

  FContext.renderbufferStorage(GL_RENDERBUFFER, (NativeView.layer as ILocalObject).GetObjectID);

  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, @FWidth);
  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, @FHeight);

  glGenRenderbuffers(1, @FDepthRenderbuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, FDepthRenderbuffer);
  if (TPlatformIOS.App.NeedStencilBuffer) then
  begin
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, FWidth, FHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, FDepthRenderbuffer);
  end
  else
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, FWidth, FHeight);
  glErrorCheck;

  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, FColorRenderbuffer);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, FDepthRenderbuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, FColorRenderbuffer);
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) <> GL_FRAMEBUFFER_COMPLETE) then
    raise Exception.Create('Unable to attach framebuffer to renderbuffer');

  glErrorCheck;
end;

procedure TGLView.CreateContext;
begin
  FContext := TEAGLContext.Wrap(TEAGLContext.Alloc.initWithAPI(kEAGLRenderingAPIOpenGLES2));
  TEAGLContext.OCClass.setCurrentContext(FContext);
end;

destructor TGLView.Destroy;
begin
  TEAGLContext.OCClass.setCurrentContext(FContext);

  if (FFramebuffer <> 0) then
    glDeleteFramebuffers(1, @FFramebuffer);

  if (FColorRenderbuffer <> 0) then
    glDeleteRenderbuffers(1, @FColorRenderbuffer);

  if (FDepthRenderbuffer <> 0) then
    glDeleteRenderbuffers(1, @FDepthRenderbuffer);

  if (FContext <> nil) then
    FContext.release;
  inherited;
end;

function TGLView.GetNativeView: UIView;
begin
  Result := UIView(Super);
end;

function TGLView.GetObjectiveCClass: PTypeInfo;
begin
  Result := TypeInfo(IGLView);
end;

class function TGLView.LayerClass(Self: Pointer; Cmd: SEL): Pointer;
begin
  { This method overrides the class method UIView.layerClass. It should return
    the layer class that is used for rendering. Since we use hardware
    accelerated OpenGLES for rendering, we need to return the CAEAGLLayer class }
  Result := objc_getClass('CAEAGLLayer');
end;

procedure TGLView.layoutSubviews;
begin
  FSizeChanged := True;
end;

procedure TGLView.RenderFrame(Sender: Pointer);
begin
  { This method is called at regular intervals by the display link to update the
    display. }

  if (FSizeChanged) then
  begin
    { Size of framebuffer has changed (probably because user rotated device).
      Update render buffer storage and retrieve new dimensions. }
    glBindRenderbuffer(GL_RENDERBUFFER, FColorRenderbuffer);
    FContext.renderbufferStorage(GL_RENDERBUFFER, (NativeView.layer as ILocalObject).GetObjectID);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, @FWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, @FHeight);

    glBindRenderbuffer(GL_RENDERBUFFER, FDepthRenderbuffer);
    if (TPlatformIOS.App.NeedStencilBuffer) then
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, FWidth, FHeight)
    else
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, FWidth, FHeight);

    TPlatformIOS.App.Resize(FWidth, FHeight);
    FSizeChanged := False;
  end;

  { Update app and render frame to back buffer }
  glBindFramebuffer(GL_FRAMEBUFFER, FFramebuffer);
  TPlatformIOS.Update;

  { Swap backbuffer to front to display it }
  glBindRenderbuffer(GL_RENDERBUFFER, FColorRenderbuffer);
  FContext.presentRenderbuffer(GL_RENDERBUFFER);
  glErrorCheck;
end;

class procedure TGLView.Setup;
var
  MetaClass: Pointer;
  Selector: SEL;
begin
  { We need to override the class method UIView.layerClass. We need to do this
    *before* an object of this type is created. To do that, we need to manually
    register our Objective-C class first, and override the "layerClass" method
    of the meta-class. }
  RegisterObjectiveCClass(TGLView, TypeInfo(IGLView));

  MetaClass := objc_getMetaClass('IGLView');
  Assert(Assigned(MetaClass));

  { Override the UIView.layerClass method and forward it to TGLView.LayerClass }
  Selector := sel_getUid('layerClass');
  if (class_addMethod(MetaClass, Selector, @LayerClass, '#@:') = 0) then
    Assert(False);
end;

procedure TGLView.Start;
var
  RunLoop: NSRunLoop;
begin
  if (FDisplayLink = nil) then
  begin
    { Create a display link to render the view at regular intervals (the screen
      refresh rate). The display link will call our RenderFrame method at those
      intervals. }
    FDisplayLink := NativeView.window.screen.displayLinkWithTarget(GetObjectID,
      sel_getUid('RenderFrame:'));

    { Add the display link to the run loop so it gets processed }
    RunLoop := TNSRunLoop.Wrap(TNSRunLoop.OCClass.currentRunLoop);
    FDisplayLink.addToRunLoop(RunLoop, NSDefaultRunLoopMode);
  end;
end;

procedure TGLView.Stop;
begin
  if (FDisplayLink <> nil) then
  begin
    FDisplayLink.invalidate;
    FDisplayLink := nil;
  end;
end;

procedure TGLView.touchesBegan(touches: NSSet; withEvent: UIEvent);
var
  View: UIView;
  Touch: UITouch;
  Location: CGPoint;
begin
  { Call "inherited" version first }
  View := NativeView;
  View.touchesBegan(touches, withEvent);

  { Convert to mouse-move and left-mouse-button-pressed events }
  Touch := TUITouch.Wrap(withEvent.allTouches.anyObject);
  Location := Touch.locationInView(View);
  TPlatformIOS.App.MouseMove([ssTouch], Location.x, Location.y);
  TPlatformIOS.App.MouseDown(TMouseButton.mbLeft, [ssTouch], Location.x, Location.y);
end;

procedure TGLView.touchesCancelled(touches: NSSet; withEvent: UIEvent);
var
  View: UIView;
  Touch: UITouch;
  Location: CGPoint;
begin
  { Call "inherited" version first }
  View := NativeView;
  View.touchesCancelled(touches, withEvent);

  { Convert to left-mouse-button-released event }
  Touch := TUITouch.Wrap(withEvent.allTouches.anyObject);
  Location := Touch.locationInView(View);
  TPlatformIOS.App.MouseUp(TMouseButton.mbLeft, [ssTouch], Location.x, Location.y);
end;

procedure TGLView.touchesEnded(touches: NSSet; withEvent: UIEvent);
var
  View: UIView;
  Touch: UITouch;
  Location: CGPoint;
begin
  { Call "inherited" version first }
  View := NativeView;
  View.touchesCancelled(touches, withEvent);

  { Convert to left-mouse-button-released event }
  Touch := TUITouch.Wrap(withEvent.allTouches.anyObject);
  Location := Touch.locationInView(View);
  TPlatformIOS.App.MouseUp(TMouseButton.mbLeft, [ssTouch], Location.x, Location.y);
end;

procedure TGLView.touchesMoved(touches: NSSet; withEvent: UIEvent);
var
  View: UIView;
  Touch: UITouch;
  Location: CGPoint;
begin
  { Call "inherited" version first }
  View := NativeView;
  View.touchesMoved(touches, withEvent);

  { Convert to mouse-move event }
  Touch := TUITouch.Wrap(withEvent.allTouches.anyObject);
  Location := Touch.locationInView(View);
  TPlatformIOS.App.MouseMove([ssTouch], Location.x, Location.y);
end;

{ TGLViewController }

function TGLViewController.GetNativeViewController: UIViewController;
begin
  Result := UIViewController(Super);
end;

function TGLViewController.GetObjectiveCClass: PTypeInfo;
begin
  Result := TypeInfo(IGLViewController);
end;

function TGLViewController.prefersStatusBarHidden: Boolean;
begin
  Result := True;
end;

function TGLViewController.shouldAutorotate: Boolean;
begin
  Result := True;
end;

{ TAppDelegate }

class procedure TAppDelegate.applicationDidBecomeActive(self: id; _cmd: SEL;
  application: PUIApplication);
begin
  FView.Start;
end;

class procedure TAppDelegate.applicationDidEnterBackground(self: id; _cmd: SEL;
  application: PUIApplication);
begin
  { TODO }
end;

class function TAppDelegate.applicationDidFinishLaunchingWithOptions(self: id;
  _cmd: SEL; application: PUIApplication; options: PNSDictionary): Boolean;
var
  Screen: UIScreen;
  Rect: CGRect;
begin
  { Create a UIWindow and TGLView that take up the entire screen. Add the
    view to the window. }
  Screen := TUIScreen.Wrap(TUIScreen.OCClass.mainScreen);
  Rect := Screen.bounds;
  FWindow := TUIWindow.Wrap(TUIWindow.Alloc.initWithFrame(Rect));
  FView := TGLView.Create(Rect);

  FWindow.addSubview(FView.NativeView);

  { Create a TGLViewController for our view, and assign it to the window }
  FViewController := TGLViewController.Create;
  FViewController.NativeViewController.setView(FView.NativeView);

  FWindow.setRootViewController(FViewController.NativeViewController);
  FWindow.makeKeyAndVisible;

  Result := True;
end;

class procedure TAppDelegate.applicationWillEnterForeground(self: id; _cmd: SEL;
  application: PUIApplication);
begin
  { TODO }
end;

class procedure TAppDelegate.applicationWillResignActive(self: id; _cmd: SEL;
  application: PUIApplication);
begin
  FView.Stop;
end;

class procedure TAppDelegate.applicationWillTerminate(self: id; _cmd: SEL;
  application: PUIApplication);
begin
  FView.Stop;
end;

class procedure TAppDelegate.Setup;
{ This method manually uses the Objective-C runtime to define and register a
  class that implements UIApplicationDelegate. If forwards the methods of
  UIApplicationDelegate to static methods of this TAppDelegate class. }
var
  DelegateClass: Pointer;
begin
  { Define a new class called AppDelegate, derived from NSObject }
  DelegateClass := objc_allocateClassPair(objc_getClass('NSObject'), DelegateName, 0);

  { Implement the UIApplicationDelegate in our class }
  class_addProtocol(DelegateClass, objc_getProtocol('UIApplicationDelegate'));

  { Add the methods from UIApplicationDelegate to our class. Note that the
    UIApplicationDelegate methods are optional, so we only implement those we
    are interested in.

    Each UIApplicationDelegate method will be forwarded to a static method in
    this class }
  class_addMethod(DelegateClass, sel_getUid('application:didFinishLaunchingWithOptions:'),
    @applicationDidFinishLaunchingWithOptions, 'B@:@@');
  class_addMethod(DelegateClass, sel_getUid('applicationDidEnterBackground:'),
    @applicationDidEnterBackground, 'v@:@');
  class_addMethod(DelegateClass, sel_getUid('applicationDidBecomeActive:'),
    @applicationDidBecomeActive, 'v@:@');
  class_addMethod(DelegateClass, sel_getUid('applicationWillEnterForeground:'),
    @applicationWillEnterForeground, 'v@:@');
  class_addMethod(DelegateClass, sel_getUid('applicationWillTerminate:'),
    @applicationWillTerminate, 'v@:@');
  class_addMethod(DelegateClass, sel_getUid('applicationWillResignActive:'),
    @applicationWillResignActive, 'v@:@');

  { Register our class, so the UIApplicationMain call can create an instance
    of it. }
  objc_registerClassPair(DelegateClass);
end;

class procedure TAppDelegate.Shutdown;
begin
  if Assigned(FWindow) then
  begin
    FWindow.release;
    FWindow := nil;
  end;
  FView.DisposeOf;
  FView := nil;
  FViewController.DisposeOf;
  FViewController := nil;
end;

end.
