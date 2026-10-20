using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Threading;

namespace GameFixerUi
{
    internal static class Theme
    {
        public static readonly Brush Bg = Freeze(0x10, 0x11, 0x14);
        public static readonly Brush Side = Freeze(0x18, 0x1A, 0x1E);
        public static readonly Brush Card = Freeze(0x1E, 0x21, 0x26);
        public static readonly Brush Card2 = Freeze(0x28, 0x2C, 0x32);
        public static readonly Brush Input = Freeze(0x12, 0x13, 0x16);
        public static readonly Brush Line = Freeze(0x00, 0x00, 0x00);
        public static readonly Brush LineStrong = Freeze(0x3A, 0x3E, 0x46);
        public static readonly Brush Red = Freeze(0xFF, 0x5C, 0x57);
        public static readonly Brush RedSoft = Freeze(0x5A, 0x32, 0x30);
        public static readonly Brush Green = Freeze(0x3D, 0xDC, 0x84);
        public static readonly Brush Yellow = Freeze(0xFE, 0xBC, 0x2E);
        public static readonly Brush Cobalt = Freeze(0x4C, 0x8D, 0xFF);
        public static readonly Brush Text = Freeze(0xF5, 0xF6, 0xF8);
        public static readonly Brush Muted = Freeze(0xB0, 0xB4, 0xBA);
        public static readonly Brush Faint = Freeze(0x8E, 0x93, 0x9A);
        public static readonly FontFamily Display = new FontFamily("Segoe UI");
        public static readonly FontFamily Ui = new FontFamily("Segoe UI");

        private static SolidColorBrush Freeze(byte r, byte g, byte b)
        {
            SolidColorBrush brush = new SolidColorBrush(Color.FromRgb(r, g, b));
            brush.Freeze();
            return brush;
        }

        private static SolidColorBrush FreezeA(byte a, byte r, byte g, byte b)
        {
            SolidColorBrush brush = new SolidColorBrush(Color.FromArgb(a, r, g, b));
            brush.Freeze();
            return brush;
        }
    }

    internal static class Lang
    {
        public static readonly bool Es;

        static Lang()
        {
            string name = CultureInfo.CurrentUICulture.Name;
            if (name == null) name = "";
            Es = name.StartsWith("es", StringComparison.OrdinalIgnoreCase);
        }

        public static string T(string es, string en)
        {
            return Es ? es : en;
        }

        public static string Page(string id)
        {
            if (id == "Inicio") return T("Inicio", "Home");
            if (id == "Reparar") return T("Reparar", "Repair");
            if (id == "Juegos") return T("Juegos", "Games");
            if (id == "Red") return T("Red", "Network");
            if (id == "Medir") return T("Medir", "Bench");
            if (id == "Soporte") return T("Soporte", "Support");
            return id;
        }
    }

    internal sealed class Act
    {
        public string Page;
        public string Id;
        public string Title;
        public string Detail;
        public bool Confirm;
    }

    internal sealed class LiveMeter
    {
        public Border Root;
        public TextBlock Value;
        public TextBlock Extra;
        public Border Fill;
        public ScaleTransform Scale;
        public System.Windows.Shapes.Polyline Spark;
        public System.Windows.Shapes.Polygon Area;
        public double[] History = new double[28];
    }

    public class AppMain
    {
        [STAThread]
        public static void Main()
        {
            Application app = new Application();
            app.Run(new Shell());
        }
    }

    internal sealed class Shell : Window
    {
        private const string Version = "3.0.1";
        private readonly TextBlock _pageTitle;
        private Border _modeButton;
        private TextBlock _modeButtonText;
        private Border _modeTestRow;
        private Border _modeLiveRow;
        private TextBlock _modeTestTitle;
        private TextBlock _modeLiveTitle;
        private Border _glowFrame;
        private Border _glowCard;
        private System.Windows.Shapes.Ellipse _glowBlob;
        private SolidColorBrush _glowInk;
        private DispatcherTimer _glowTimer;
        private double _glowTravel;
        private readonly WrapPanel _cards;
        private readonly UniformGrid _meterHost;
        private readonly List<LiveMeter> _meters = new List<LiveMeter>();
        private readonly TextBox _log;
        private TextBlock _statusTitle;
        private TextBlock _statusBody;
        private TextBlock _lead;
        private StackPanel _steps;
        private ScrollViewer _stepsScroll;
        private string _actId;
        private string _resultLead;
        private Border _foundHost;
        private TextBlock _foundTitle;
        private WrapPanel _foundWrap;
        private Border _startupHost;
        private TextBlock _startupTitle;
        private WrapPanel _startupWrap;
        private Border _historyHost;
        private StackPanel _historyList;
        private Border _benchHost;
        private StackPanel _benchList;
        private Border _driverLink;
        private string _driverUrl;
        private string _actTitle;
        private ScaleTransform _barScale;
        private Border _barFill;
        private TextBlock _pctLabel;
        private Border _codeCard;
        private TextBox _codeText;
        private TextBlock _copyLabel;
        private TextBlock _pageCopyLabel;
        private string _supportCode;
        private Border _pageCodeCard;
        private TextBox _pageCodeText;
        private bool _sawProblem;
        private bool _sawFinding;
        private bool _sawResult;
        private bool _lastConfirm;
        private int _exitCode;
        private readonly object _payloadLock = new object();
        private string _payloadRoot;
        private readonly Border _busy;
        private readonly TextBlock _busyText;
        private readonly Canvas _sky;
        private readonly Button[] _nav;
        private Border _side;
        private ScrollViewer _scroll;
        private string _page = "Inicio";
        private string _supportPending;
        private bool _live;
        private bool _busyFlag;
        private Process _proc;
        private PerformanceCounter _cpu;
        private PerformanceCounter _disk;
        private readonly List<PerformanceCounter> _vram = new List<PerformanceCounter>();
        private readonly Dictionary<string, PerformanceCounter> _gpuEngines = new Dictionary<string, PerformanceCounter>();
        private readonly Dictionary<string, CounterSample> _gpuPrev = new Dictionary<string, CounterSample>();
        private System.Threading.Timer _gpuSampler;
        private double _gpuPct;
        private bool _gpuLive;
        private int _gpuBusy;
        private int _gpuScan;
        private readonly List<PerformanceCounter> _rx = new List<PerformanceCounter>();
        private readonly List<PerformanceCounter> _tx = new List<PerformanceCounter>();
        private readonly DispatcherTimer _tick;

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

        [DllImport("user32.dll")]
        private static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct MEMORYSTATUSEX
        {
            public uint dwLength;
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;
        }

        public Shell()
        {
            Title = "Game Fixer " + Version;
            Width = 1360;
            Height = 880;
            MinWidth = 980;
            MinHeight = 680;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            ResizeMode = ResizeMode.CanResize;
            Background = Brushes.Transparent;
            FontFamily = Theme.Ui;
            InstallDarkScroll();
            SizeChanged += delegate { Reflow(); };

            Act[] acts = BuildActs();

            Border frame = new Border();
            frame.Margin = new Thickness(16);
            frame.CornerRadius = new CornerRadius(14);
            frame.BorderBrush = Theme.LineStrong;
            frame.BorderThickness = new Thickness(1);
            frame.Background = NightBrush();
            frame.ClipToBounds = true;
            DropShadowEffect glow = new DropShadowEffect();
            glow.Color = Colors.Black;
            glow.BlurRadius = 36;
            glow.ShadowDepth = 0;
            glow.Opacity = 0.55;
            frame.Effect = glow;
            Content = frame;

            DockPanel root = new DockPanel();
            Grid host = new Grid();
            host.Children.Add(root);
            AddResizeEdges(host);
            frame.Child = host;

            root.Children.Add(BuildTitle());
            root.Children.Add(BuildFooter());
            _meterHost = new UniformGrid();
            _meterHost.Columns = 5;
            _meterHost.Rows = 1;
            root.Children.Add(BuildMeterBand());

            _side = new Border();
            Border side = _side;
            side.Width = 248;
            side.Background = Theme.Side;
            side.BorderBrush = Brushes.Black;
            side.BorderThickness = new Thickness(0, 0, 8, 0);
            DockPanel.SetDock(side, Dock.Left);
            root.Children.Add(side);

            StackPanel sideStack = new StackPanel();
            side.Child = sideStack;

            sideStack.Children.Add(BuildLogo());

            string[] pages = new string[] { "Inicio", "Reparar", "Juegos", "Red", "Medir", "Soporte" };
            _nav = new Button[pages.Length];
            for (int i = 0; i < pages.Length; i++)
            {
                Button b = NavButton(pages[i]);
                _nav[i] = b;
                sideStack.Children.Add(b);
            }

            sideStack.Children.Add(BuildModeSwitch());
            PaintMode();

            Grid main = new Grid();
            main.ClipToBounds = true;
            root.Children.Add(main);
            main.RowDefinitions.Add(new RowDefinition { Height = new GridLength(3.2, GridUnitType.Star) });
            main.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            _sky = new Canvas();
            _sky.IsHitTestVisible = false;
            _sky.Background = Brushes.Transparent;
            Grid.SetRowSpan(_sky, 2);
            main.Children.Add(_sky);
            BuildWash();

            Grid top = new Grid();
            top.Margin = new Thickness(28, 18, 28, 8);
            top.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            top.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            top.RowDefinitions.Add(new RowDefinition());
            Grid.SetRow(top, 0);
            main.Children.Add(top);

            DockPanel head = new DockPanel();
            Grid.SetRow(head, 0);
            top.Children.Add(head);

            _pageTitle = new TextBlock();
            _pageTitle.Foreground = Theme.Text;
            _pageTitle.FontFamily = Theme.Display;
            _pageTitle.FontSize = 32;
            _pageTitle.FontWeight = FontWeights.SemiBold;
            head.Children.Add(_pageTitle);

            TextBlock lead = new TextBlock();
            _lead = lead;
            lead.Text = Lang.T("Pulsa una tarjeta. Abajo te diremos qué hace y si tu PC cambió.", "Click a card. Below you'll see what it does and whether your PC changed.");
            lead.Foreground = Theme.Muted;
            lead.Margin = new Thickness(0, 6, 0, 16);
            Grid.SetRow(lead, 1);
            top.Children.Add(lead);

            _scroll = new ScrollViewer();
            _scroll.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            _scroll.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
            _scroll.Background = Brushes.Transparent;
            Grid.SetRow(_scroll, 2);
            top.Children.Add(_scroll);
            StackPanel pageStack = new StackPanel();
            _foundHost = new Border();
            _foundHost.Visibility = Visibility.Collapsed;
            _foundHost.Background = Theme.Card;
            _foundHost.BorderBrush = Theme.Line;
            _foundHost.BorderThickness = new Thickness(1);
            _foundHost.CornerRadius = new CornerRadius(12);
            _foundHost.Padding = new Thickness(14, 12, 14, 12);
            _foundHost.Margin = new Thickness(0, 0, 14, 14);
            StackPanel foundStack = new StackPanel();
            _foundHost.Child = foundStack;
            _foundTitle = new TextBlock();
            _foundTitle.Foreground = Theme.Text;
            _foundTitle.FontSize = 16;
            _foundTitle.FontWeight = FontWeights.SemiBold;
            _foundTitle.Text = Lang.T("Juegos encontrados", "Games found");
            foundStack.Children.Add(_foundTitle);
            _foundWrap = new WrapPanel();
            _foundWrap.Margin = new Thickness(0, 10, 0, 0);
            foundStack.Children.Add(_foundWrap);
            pageStack.Children.Add(_foundHost);
            TextBlock historyTitle;
            Panel historyBody;
            _historyHost = NoteHost(Lang.T("Últimas acciones", "Recent actions"), false, out historyTitle, out historyBody);
            _historyList = (StackPanel)historyBody;
            pageStack.Children.Add(_historyHost);
            Panel startupBody;
            _startupHost = NoteHost(Lang.T("Programas de inicio", "Startup programs"), true, out _startupTitle, out startupBody);
            _startupWrap = (WrapPanel)startupBody;
            pageStack.Children.Add(_startupHost);
            TextBlock benchTitle;
            Panel benchBody;
            _benchHost = NoteHost(Lang.T("Comparado con la vez anterior", "Compared with last time"), false, out benchTitle, out benchBody);
            _benchList = (StackPanel)benchBody;
            pageStack.Children.Add(_benchHost);
            _cards = new WrapPanel();
            pageStack.Children.Add(_cards);
            _scroll.Content = pageStack;

            _busy = new Border();
            _busy.Background = new SolidColorBrush(Color.FromArgb(0xCC, 0x0A, 0x0A, 0x0E));
            _busy.Visibility = Visibility.Collapsed;
            _busy.CornerRadius = new CornerRadius(12);
            Grid.SetRow(_busy, 2);
            top.Children.Add(_busy);
            StackPanel busyStack = new StackPanel();
            busyStack.HorizontalAlignment = HorizontalAlignment.Center;
            busyStack.VerticalAlignment = VerticalAlignment.Center;
            _busy.Child = busyStack;
            busyStack.Children.Add(BuildSpinner());
            _busyText = new TextBlock();
            _busyText.Foreground = Theme.Text;
            _busyText.FontSize = 16;
            _busyText.Margin = new Thickness(0, 14, 0, 0);
            _busyText.HorizontalAlignment = HorizontalAlignment.Center;
            busyStack.Children.Add(_busyText);

            Border logFrame = new Border();
            logFrame.Margin = new Thickness(28, 0, 28, 16);
            logFrame.Background = Theme.Card;
            logFrame.BorderBrush = Brushes.Black;
            logFrame.BorderThickness = new Thickness(0, 8, 0, 0);
            logFrame.Background = Theme.Card;
            logFrame.CornerRadius = new CornerRadius(12);
            logFrame.Padding = new Thickness(14, 10, 14, 10);
            logFrame.MaxHeight = 230;
            logFrame.VerticalAlignment = VerticalAlignment.Bottom;
            Grid.SetRow(logFrame, 1);
            main.Children.Add(logFrame);

            DockPanel logDock = new DockPanel();
            logFrame.Child = logDock;

            DockPanel headRow = new DockPanel();
            DockPanel.SetDock(headRow, Dock.Top);
            Button detail = new Button();
            detail.Content = Lang.T("Ver detalle técnico", "Show technical detail");
            detail.Background = Brushes.Transparent;
            detail.Foreground = Theme.Muted;
            detail.BorderBrush = Theme.LineStrong;
            detail.BorderThickness = new Thickness(1);
            detail.Padding = new Thickness(10, 4, 10, 4);
            detail.Template = FlatTemplate();
            detail.Cursor = Cursors.Hand;
            detail.HorizontalAlignment = HorizontalAlignment.Right;
            DockPanel.SetDock(detail, Dock.Right);
            headRow.Children.Add(detail);
            TextBlock logHead = new TextBlock();
            logHead.Text = Lang.T("QUÉ ESTÁ PASANDO", "WHAT'S HAPPENING");
            logHead.Foreground = Theme.Faint;
            logHead.FontSize = 11;
            logHead.VerticalAlignment = VerticalAlignment.Center;
            headRow.Children.Add(logHead);
            logDock.Children.Add(headRow);

            DockPanel titleRow = new DockPanel();
            DockPanel.SetDock(titleRow, Dock.Top);
            titleRow.Margin = new Thickness(0, 8, 0, 0);
            _statusTitle = new TextBlock();
            _statusTitle.Text = Lang.T("Todavía no has ejecutado nada", "Nothing has run yet");
            _statusTitle.Foreground = Theme.Text;
            _statusTitle.FontSize = 22;
            _statusTitle.FontWeight = FontWeights.SemiBold;
            _statusTitle.VerticalAlignment = VerticalAlignment.Center;
            titleRow.Children.Add(_statusTitle);
            logDock.Children.Add(titleRow);

            Grid barRow = new Grid();
            barRow.Margin = new Thickness(0, 10, 0, 4);
            DockPanel.SetDock(barRow, Dock.Top);
            barRow.ColumnDefinitions.Add(new ColumnDefinition());
            barRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            Border track = new Border();
            track.Height = 14;
            track.CornerRadius = new CornerRadius(7);
            track.Background = Theme.Card2;
            track.ClipToBounds = true;
            _barFill = new Border();
            _barFill.Background = Theme.Cobalt;
            _barFill.CornerRadius = new CornerRadius(7);
            _barScale = new ScaleTransform(0, 1);
            _barFill.RenderTransform = _barScale;
            _barFill.RenderTransformOrigin = new Point(0, 0.5);
            track.Child = _barFill;
            barRow.Children.Add(track);
            _pctLabel = new TextBlock();
            _pctLabel.Text = "0%";
            _pctLabel.FontSize = 26;
            _pctLabel.FontWeight = FontWeights.Black;
            _pctLabel.Foreground = Theme.Faint;
            _pctLabel.Margin = new Thickness(16, 0, 2, 0);
            _pctLabel.VerticalAlignment = VerticalAlignment.Center;
            Grid.SetColumn(_pctLabel, 1);
            barRow.Children.Add(_pctLabel);
            logDock.Children.Add(barRow);

            _codeCard = new Border();
            _codeCard.Visibility = Visibility.Collapsed;
            _codeCard.Background = Theme.Bg;
            _codeCard.BorderBrush = Theme.Green;
            _codeCard.BorderThickness = new Thickness(1);
            _codeCard.CornerRadius = new CornerRadius(12);
            _codeCard.Padding = new Thickness(16, 12, 16, 12);
            _codeCard.Margin = new Thickness(0, 8, 0, 8);
            DockPanel.SetDock(_codeCard, Dock.Top);
            DockPanel codeRow = new DockPanel();
            _codeCard.Child = codeRow;
            Border copy = new Border();
            copy.Background = Theme.Card2;
            copy.BorderBrush = Theme.LineStrong;
            copy.BorderThickness = new Thickness(1);
            copy.CornerRadius = new CornerRadius(8);
            copy.Padding = new Thickness(14, 8, 14, 8);
            copy.Cursor = Cursors.Hand;
            copy.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(copy, Dock.Right);
            _copyLabel = new TextBlock();
            _copyLabel.Text = Lang.T("Copiar", "Copy");
            _copyLabel.Foreground = Theme.Text;
            _copyLabel.FontWeight = FontWeights.SemiBold;
            _copyLabel.FontSize = 14;
            copy.Child = _copyLabel;
            copy.MouseLeftButtonUp += delegate { CopySupportCode(); };
            codeRow.Children.Add(copy);
            StackPanel codeText = new StackPanel();
            codeRow.Children.Add(codeText);
            TextBlock codeCap = new TextBlock();
            codeCap.Text = Lang.T("TU CÓDIGO", "YOUR CODE");
            codeCap.Foreground = Theme.Faint;
            codeCap.FontSize = 11;
            codeText.Children.Add(codeCap);
            _codeText = CodeBox();
            _codeText.Margin = new Thickness(0, 2, 12, 0);
            codeText.Children.Add(_codeText);
            logDock.Children.Add(_codeCard);

            _statusBody = new TextBlock();
            _statusBody.Text = Lang.T("Cuando pulses una acción, aquí verás en claro qué hace y si tu equipo cambia. El modo prueba no toca nada.", "When you run an action, this explains what it does and whether your PC changes. Test mode changes nothing.");
            _statusBody.Foreground = Theme.Muted;
            _statusBody.FontSize = 15;
            _statusBody.TextWrapping = TextWrapping.Wrap;
            _statusBody.Margin = new Thickness(0, 4, 0, 8);
            DockPanel.SetDock(_statusBody, Dock.Top);
            logDock.Children.Add(_statusBody);

            _driverLink = new Border();
            _driverLink.Visibility = Visibility.Collapsed;
            _driverLink.Background = Theme.Card2;
            _driverLink.BorderBrush = Theme.Cobalt;
            _driverLink.BorderThickness = new Thickness(1);
            _driverLink.CornerRadius = new CornerRadius(8);
            _driverLink.Padding = new Thickness(12, 7, 12, 7);
            _driverLink.Margin = new Thickness(0, 0, 0, 8);
            _driverLink.HorizontalAlignment = HorizontalAlignment.Left;
            _driverLink.Cursor = Cursors.Hand;
            DockPanel.SetDock(_driverLink, Dock.Top);
            TextBlock driverText = new TextBlock();
            driverText.Text = Lang.T("Abrir página del driver", "Open driver page");
            driverText.Foreground = Theme.Cobalt;
            driverText.FontWeight = FontWeights.SemiBold;
            driverText.FontSize = 14;
            _driverLink.Child = driverText;
            _driverLink.MouseLeftButtonUp += delegate { OpenDriverPage(); };
            logDock.Children.Add(_driverLink);

            _stepsScroll = new ScrollViewer();
            _stepsScroll.MaxHeight = 72;
            _stepsScroll.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            _stepsScroll.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
            DockPanel.SetDock(_stepsScroll, Dock.Top);
            _steps = new StackPanel();
            _stepsScroll.Content = _steps;
            logDock.Children.Add(_stepsScroll);

            _log = new TextBox();
            _log.Background = Theme.Input;
            _log.Foreground = Theme.Muted;
            _log.BorderThickness = new Thickness(0);
            _log.FontFamily = new FontFamily("Consolas");
            _log.FontSize = 12;
            _log.IsReadOnly = true;
            _log.AcceptsReturn = true;
            _log.TextWrapping = TextWrapping.Wrap;
            _log.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            _log.Height = 0;
            _log.Visibility = Visibility.Collapsed;
            _log.Margin = new Thickness(0, 8, 0, 0);
            _log.Padding = new Thickness(8);
            logDock.Children.Add(_log);
            detail.Click += delegate
            {
                bool open = _log.Visibility != Visibility.Visible;
                _log.Visibility = open ? Visibility.Visible : Visibility.Collapsed;
                _log.Height = open ? 120 : 0;
                detail.Content = open ? Lang.T("Ocultar detalle", "Hide detail") : Lang.T("Ver detalle técnico", "Show technical detail");
            };

            ShowPage(acts);
            PaintNav();

            _tick = new DispatcherTimer();
            _tick.Interval = TimeSpan.FromSeconds(1);
            _tick.Tick += delegate { TickMeters(); };
            _tick.Start();

            Loaded += delegate
            {
                PlaceWash();
                Reflow();
                ThreadPool.QueueUserWorkItem(delegate { WarmPayload(); });
                ThreadPool.QueueUserWorkItem(delegate { InitLiveCounters(); });
                _gpuSampler = new System.Threading.Timer(delegate { SampleGpu(); }, null, 600, 1000);
            };
            Closing += delegate
            {
                if (_gpuSampler != null) _gpuSampler.Dispose();
                StopProc();
            };
        }

        private UIElement BuildFooter()
        {
            DockPanel row = new DockPanel();
            row.Margin = new Thickness(16, 6, 14, 8);
            FrameworkElement discord = DiscordButton();
            DockPanel.SetDock(discord, Dock.Right);
            discord.Margin = new Thickness(12, 0, 0, 0);
            row.Children.Add(discord);

            TextBlock line = new TextBlock();
            line.Foreground = Theme.Muted;
            line.FontSize = 12;
            line.TextWrapping = TextWrapping.Wrap;
            line.VerticalAlignment = VerticalAlignment.Center;
            line.Text = Lang.T("© 2026 FamiliaCuba. Todos los derechos reservados.   Game Fixer v", "© 2026 FamiliaCuba. All rights reserved.   Game Fixer v") + Version + Lang.T("   ·   Licencia MIT", "   ·   MIT License");
            row.Children.Add(line);

            Border bar = new Border();
            bar.Background = Theme.Bg;
            bar.Child = row;
            DockPanel.SetDock(bar, Dock.Bottom);
            Panel.SetZIndex(bar, 8);
            return bar;
        }

        private FrameworkElement DiscordButton()
        {
            Border mark = new Border();
            mark.Width = 28;
            mark.Height = 28;
            mark.CornerRadius = new CornerRadius(8);
            mark.Background = new SolidColorBrush(Color.FromRgb(0x58, 0x65, 0xF2));
            mark.Cursor = Cursors.Hand;
            mark.ToolTip = "Discord";
            Viewbox box = new Viewbox();
            box.Width = 16;
            box.Height = 16;
            System.Windows.Shapes.Path glyph = new System.Windows.Shapes.Path();
            glyph.Fill = Brushes.White;
            glyph.Data = Geometry.Parse("M20.3 4.4a19.8 19.8 0 0 0-4.9-1.5.07.07 0 0 0-.08.04c-.2.4-.4.9-.6 1.2a18.3 18.3 0 0 0-5.5 0 12.6 12.6 0 0 0-.6-1.2.08.08 0 0 0-.08-.04A19.7 19.7 0 0 0 3.7 4.4a.07.07 0 0 0-.03.03C.5 9-.3 13.6.1 18.1a.08.08 0 0 0 .03.05 19.9 19.9 0 0 0 6 3 .08.08 0 0 0 .08-.03 14 14 0 0 0 1.2-2 .08.08 0 0 0-.04-.1 13 13 0 0 1-1.9-.9.08.08 0 0 1 0-.13l.4-.3a.07.07 0 0 1 .07-.01c3.9 1.8 8.2 1.8 12.1 0a.07.07 0 0 1 .07.01c.2.1.4.2.4.3a.08.08 0 0 1 0 .13 12.3 12.3 0 0 1-1.9.9.08.08 0 0 0-.04.1c.4.7.8 1.4 1.2 2a.08.08 0 0 0 .09.03 19.8 19.8 0 0 0 6-3 .08.08 0 0 0 .03-.06c.5-5.2-.8-9.7-3.5-13.7a.06.06 0 0 0-.03-.03zM8 15.3c-1.2 0-2.2-1.1-2.2-2.4 0-1.3 1-2.4 2.2-2.4 1.2 0 2.2 1.1 2.2 2.4 0 1.3-1 2.4-2.2 2.4zm8 0c-1.2 0-2.2-1.1-2.2-2.4 0-1.3 1-2.4 2.2-2.4 1.2 0 2.2 1.1 2.1 2.4 0 1.3-.9 2.4-2.1 2.4z");
            box.Child = glyph;
            mark.Child = box;

            Border card = new Border();
            card.Background = Theme.Card;
            card.BorderBrush = new SolidColorBrush(Color.FromRgb(0x58, 0x65, 0xF2));
            card.BorderThickness = new Thickness(1);
            card.CornerRadius = new CornerRadius(12);
            card.Padding = new Thickness(12, 10, 12, 10);
            card.Width = 230;
            card.HorizontalAlignment = HorizontalAlignment.Right;
            card.VerticalAlignment = VerticalAlignment.Top;
            DropShadowEffect glow = new DropShadowEffect();
            glow.Color = Color.FromRgb(0x58, 0x65, 0xF2);
            glow.BlurRadius = 18;
            glow.ShadowDepth = 0;
            glow.Opacity = 0.45;
            card.Effect = glow;
            StackPanel stack = new StackPanel();
            card.Child = stack;
            TextBlock title = new TextBlock();
            title.Text = "Familia Cuba";
            title.Foreground = Theme.Text;
            title.FontWeight = FontWeights.SemiBold;
            title.FontSize = 14;
            stack.Children.Add(title);
            TextBlock body = new TextBlock();
            body.Text = Lang.T("Entra al Discord para soporte y novedades.", "Join Discord for support and news.");
            body.Foreground = Theme.Muted;
            body.FontSize = 12;
            body.TextWrapping = TextWrapping.Wrap;
            body.Margin = new Thickness(0, 4, 0, 10);
            stack.Children.Add(body);
            Button go = new Button();
            go.Content = Lang.T("Conectar", "Connect");
            go.Background = new SolidColorBrush(Color.FromRgb(0x58, 0x65, 0xF2));
            go.Foreground = Brushes.White;
            go.BorderThickness = new Thickness(0);
            go.Padding = new Thickness(12, 6, 12, 6);
            go.Template = FlatTemplate();
            go.Cursor = Cursors.Hand;
            go.HorizontalAlignment = HorizontalAlignment.Left;
            go.Click += delegate { OpenDiscord(); };
            stack.Children.Add(go);

            System.Windows.Shapes.Path arrow = new System.Windows.Shapes.Path();
            arrow.Fill = Theme.Card;
            arrow.Data = Geometry.Parse("M0,0 L10,0 L5,7 Z");
            arrow.Width = 10;
            arrow.Height = 7;
            arrow.HorizontalAlignment = HorizontalAlignment.Right;
            arrow.VerticalAlignment = VerticalAlignment.Bottom;
            arrow.Margin = new Thickness(0, 0, 9, -6);
            arrow.IsHitTestVisible = false;

            Grid bubble = new Grid();
            bubble.Width = 230;
            bubble.Children.Add(card);
            bubble.Children.Add(arrow);
            ScaleTransform scale = new ScaleTransform(0.82, 0.82);
            TranslateTransform rise = new TranslateTransform(0, 10);
            TransformGroup motion = new TransformGroup();
            motion.Children.Add(scale);
            motion.Children.Add(rise);
            bubble.RenderTransform = motion;
            bubble.RenderTransformOrigin = new Point(1, 1);
            bubble.Opacity = 0;
            bubble.IsHitTestVisible = false;

            Canvas nest = new Canvas();
            nest.Width = 28;
            nest.Height = 28;
            nest.ClipToBounds = false;
            Canvas.SetRight(bubble, 0);
            Canvas.SetBottom(bubble, 36);
            nest.Children.Add(bubble);
            Canvas.SetLeft(mark, 0);
            Canvas.SetTop(mark, 0);
            nest.Children.Add(mark);

            Duration showTime = TimeSpan.FromMilliseconds(220);
            CubicEase ease = new CubicEase();
            ease.EasingMode = EasingMode.EaseOut;
            Action showTip = delegate
            {
                bubble.IsHitTestVisible = true;
                DoubleAnimation fade = new DoubleAnimation(1, showTime);
                fade.EasingFunction = ease;
                bubble.BeginAnimation(UIElement.OpacityProperty, fade);
                DoubleAnimation grow = new DoubleAnimation(1, showTime);
                grow.EasingFunction = ease;
                scale.BeginAnimation(ScaleTransform.ScaleXProperty, grow);
                scale.BeginAnimation(ScaleTransform.ScaleYProperty, grow);
                DoubleAnimation up = new DoubleAnimation(0, showTime);
                up.EasingFunction = ease;
                rise.BeginAnimation(TranslateTransform.YProperty, up);
            };
            Action hideTip = delegate
            {
                bubble.IsHitTestVisible = false;
                Duration hideTime = TimeSpan.FromMilliseconds(140);
                bubble.BeginAnimation(UIElement.OpacityProperty, new DoubleAnimation(0, hideTime));
                scale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(0.82, hideTime));
                scale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(0.82, hideTime));
                rise.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(10, hideTime));
            };

            DispatcherTimer hide = new DispatcherTimer();
            hide.Interval = TimeSpan.FromMilliseconds(180);
            bool over = false;
            hide.Tick += delegate
            {
                hide.Stop();
                if (!over) hideTip();
            };
            MouseEventHandler enter = delegate { over = true; hide.Stop(); showTip(); };
            MouseEventHandler leave = delegate { over = false; hide.Start(); };
            mark.MouseEnter += enter;
            mark.MouseLeave += leave;
            bubble.MouseEnter += enter;
            bubble.MouseLeave += leave;
            mark.MouseLeftButtonUp += delegate { OpenDiscord(); };
            return nest;
        }

        private static void OpenDiscord()
        {
            try { Process.Start("https://discord.gg/WecrFkBGGx"); }
            catch { }
        }

        private Border BuildMeterBand()
        {
            Border band = new Border();
            band.BorderBrush = Brushes.Black;
            band.BorderThickness = new Thickness(0, 8, 0, 0);
            band.Background = Theme.Side;
            band.Padding = new Thickness(22, 12, 22, 16);
            DockPanel.SetDock(band, Dock.Bottom);

            StackPanel col = new StackPanel();
            band.Child = col;
            TextBlock cap = new TextBlock();
            cap.Text = Lang.T("EN VIVO", "LIVE");
            cap.Foreground = Theme.Faint;
            cap.FontSize = 11;
            cap.Margin = new Thickness(6, 0, 0, 8);
            col.Children.Add(cap);
            col.Children.Add(_meterHost);
            AddMeter("CPU");
            AddMeter("RAM");
            AddMeter("GPU");
            AddMeter(Lang.T("DISCO", "DISK"));
            AddMeter(Lang.T("RED", "NET"));
            return band;
        }

        private UIElement BuildTitle()
        {
            Border bar = new Border();
            bar.Height = 42;
            bar.Background = Brushes.Transparent;
            bar.BorderBrush = Brushes.Black;
            bar.BorderThickness = new Thickness(0, 0, 0, 1);
            DockPanel.SetDock(bar, Dock.Top);
            bar.MouseLeftButtonDown += delegate { DragMove(); };

            DockPanel dock = new DockPanel();
            bar.Child = dock;

            StackPanel lights = new StackPanel();
            lights.Orientation = Orientation.Horizontal;
            lights.Margin = new Thickness(0, 0, 12, 0);
            lights.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(lights, Dock.Right);
            lights.Children.Add(Traffic(Color.FromRgb(0xFE, 0xBC, 0x2E), delegate { WindowState = WindowState.Minimized; }));
            lights.Children.Add(Traffic(Color.FromRgb(0x28, 0xC8, 0x40), delegate
            {
                WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
            }));
            lights.Children.Add(Traffic(Color.FromRgb(0xFF, 0x5F, 0x57), delegate { Close(); }));
            dock.Children.Add(lights);

            TextBlock t = new TextBlock();
            t.Text = "Game Fixer";
            t.FontFamily = Theme.Ui;
            t.FontSize = 13;
            t.FontWeight = FontWeights.SemiBold;
            t.Foreground = Theme.Muted;
            t.VerticalAlignment = VerticalAlignment.Center;
            t.Margin = new Thickness(16, 0, 0, 0);
            dock.Children.Add(t);
            return bar;
        }

        private Border Traffic(Color color, Action click)
        {
            Border dot = new Border();
            dot.Width = 15;
            dot.Height = 15;
            dot.CornerRadius = new CornerRadius(8);
            dot.Background = new SolidColorBrush(color);
            dot.Margin = new Thickness(0, 0, 8, 0);
            dot.Cursor = Cursors.Hand;
            dot.MouseLeftButtonDown += delegate(object s, MouseButtonEventArgs e)
            {
                e.Handled = true;
                click();
            };
            return dot;
        }

        private Button Chrome(string text, Action click)
        {
            Button b = new Button();
            b.Content = text;
            b.Width = 42;
            b.HorizontalContentAlignment = HorizontalAlignment.Center;
            b.Background = Brushes.Transparent;
            b.Foreground = Theme.Muted;
            b.BorderThickness = new Thickness(0);
            b.Template = FlatTemplate();
            b.Cursor = Cursors.Hand;
            b.Click += delegate { click(); };
            return b;
        }

        private Button NavButton(string page)
        {
            Button b = new Button();
            b.Content = Lang.Page(page);
            b.Tag = page;
            b.HorizontalContentAlignment = HorizontalAlignment.Left;
            b.Margin = new Thickness(14, 3, 14, 3);
            b.Padding = new Thickness(16, 9, 16, 9);
            b.FontSize = 14;
            b.FontFamily = Theme.Ui;
            b.Template = FlatTemplate();
            b.Cursor = Cursors.Hand;
            b.Click += delegate { _page = page; ShowPage(BuildActs()); PaintNav(); };
            return b;
        }

        private void PaintNav()
        {
            for (int i = 0; i < _nav.Length; i++)
            {
                bool on = (string)_nav[i].Tag == _page;
                _nav[i].Background = on ? Theme.Card2 : Brushes.Transparent;
                _nav[i].Foreground = on ? Theme.Text : Theme.Muted;
                _nav[i].BorderBrush = on ? Theme.LineStrong : Brushes.Transparent;
                _nav[i].BorderThickness = new Thickness(1);
            }
        }

        private void AddMeter(string name)
        {
            LiveMeter m = new LiveMeter();
            Border root = new Border();
            root.Background = Theme.Card;
            root.BorderBrush = Theme.Line;
            root.BorderThickness = new Thickness(1);
            root.CornerRadius = new CornerRadius(12);
            root.Padding = new Thickness(12, 8, 12, 8);
            root.Margin = new Thickness(6);
            m.Root = root;

            StackPanel stack = new StackPanel();
            root.Child = stack;
            DockPanel topLine = new DockPanel();
            TextBlock label = new TextBlock();
            label.Text = name;
            label.Foreground = Theme.Faint;
            label.FontSize = 11;
            label.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(label, Dock.Left);
            topLine.Children.Add(label);
            m.Value = new TextBlock();
            m.Value.Text = "—";
            m.Value.Foreground = Theme.Text;
            m.Value.FontFamily = new FontFamily("Consolas");
            m.Value.FontSize = 18;
            m.Value.HorizontalAlignment = HorizontalAlignment.Right;
            topLine.Children.Add(m.Value);
            stack.Children.Add(topLine);

            Border track = new Border();
            track.Height = 4;
            track.Margin = new Thickness(0, 8, 0, 0);
            track.Background = Theme.Side;
            track.CornerRadius = new CornerRadius(2);
            track.ClipToBounds = true;
            m.Fill = new Border();
            m.Fill.Background = Theme.Green;
            m.Scale = new ScaleTransform(0, 1);
            m.Fill.RenderTransform = m.Scale;
            m.Fill.RenderTransformOrigin = new Point(0, 0.5);
            track.Child = m.Fill;
            stack.Children.Add(track);

            Grid chart = new Grid();
            chart.Height = 36;
            chart.Margin = new Thickness(0, 6, 0, 0);
            chart.ClipToBounds = true;
            m.Area = new System.Windows.Shapes.Polygon();
            m.Area.Fill = Theme.Green;
            m.Spark = new System.Windows.Shapes.Polyline();
            m.Spark.Stroke = Theme.Green;
            m.Spark.StrokeThickness = 2.2;
            m.Spark.StrokeLineJoin = PenLineJoin.Round;
            chart.Children.Add(m.Area);
            chart.Children.Add(m.Spark);
            stack.Children.Add(chart);

            m.Extra = new TextBlock();
            m.Extra.Foreground = Theme.Muted;
            m.Extra.FontSize = 11;
            m.Extra.Margin = new Thickness(0, 2, 0, 0);
            m.Extra.Text = " ";
            stack.Children.Add(m.Extra);

            _meters.Add(m);
            _meterHost.Children.Add(root);
        }

        private void InitLiveCounters()
        {
            PerformanceCounter cpu = null;
            PerformanceCounter disk = null;
            List<PerformanceCounter> vram = new List<PerformanceCounter>();
            List<PerformanceCounter> rx = new List<PerformanceCounter>();
            List<PerformanceCounter> tx = new List<PerformanceCounter>();
            try
            {
                cpu = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                cpu.NextValue();
            }
            catch { cpu = null; }
            try
            {
                disk = new PerformanceCounter("PhysicalDisk", "Disk Bytes/sec", "_Total");
                disk.NextValue();
            }
            catch { disk = null; }
            AddInstances("GPU Adapter Memory", "Dedicated Usage", null, vram);
            AddInstances("Network Interface", "Bytes Received/sec", null, rx);
            AddInstances("Network Interface", "Bytes Sent/sec", null, tx);
            Dispatcher.BeginInvoke(new Action(delegate
            {
                _cpu = cpu;
                _disk = disk;
                _vram.AddRange(vram);
                _rx.AddRange(rx);
                _tx.AddRange(tx);
            }));
        }

        private static void AddInstances(string category, string counter, string need, List<PerformanceCounter> list)
        {
            try
            {
                string[] names = new PerformanceCounterCategory(category).GetInstanceNames();
                for (int i = 0; i < names.Length; i++)
                {
                    if (list.Count >= 8) break;
                    string n = names[i];
                    if (need != null && n.IndexOf(need, StringComparison.OrdinalIgnoreCase) < 0) continue;
                    if (n.IndexOf("loopback", StringComparison.OrdinalIgnoreCase) >= 0) continue;
                    if (n.IndexOf("isatap", StringComparison.OrdinalIgnoreCase) >= 0) continue;
                    if (n.IndexOf("teredo", StringComparison.OrdinalIgnoreCase) >= 0) continue;
                    PerformanceCounter pc = new PerformanceCounter(category, counter, n);
                    pc.NextValue();
                    list.Add(pc);
                }
            }
            catch { }
        }

        private static double Sum(List<PerformanceCounter> list)
        {
            double total = 0;
            for (int i = 0; i < list.Count; i++)
            {
                try { total += list[i].NextValue(); }
                catch { }
            }
            return total;
        }

        private static ControlTemplate FlatTemplate()
        {
            FrameworkElementFactory border = new FrameworkElementFactory(typeof(Border));
            border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Control.BackgroundProperty));
            border.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Control.BorderBrushProperty));
            border.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Control.BorderThicknessProperty));
            border.SetValue(Border.CornerRadiusProperty, new CornerRadius(8));
            border.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Control.PaddingProperty));
            FrameworkElementFactory content = new FrameworkElementFactory(typeof(ContentPresenter));
            content.SetValue(FrameworkElement.HorizontalAlignmentProperty, new TemplateBindingExtension(Control.HorizontalContentAlignmentProperty));
            content.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
            border.AppendChild(content);
            ControlTemplate template = new ControlTemplate(typeof(Button));
            template.VisualTree = border;
            return template;
        }

        private static Brush NightBrush()
        {
            LinearGradientBrush brush = new LinearGradientBrush();
            brush.StartPoint = new Point(0, 0);
            brush.EndPoint = new Point(1, 1);
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(0x16, 0x18, 0x1C), 0));
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(0x0C, 0x0D, 0x10), 1));
            brush.Freeze();
            return brush;
        }

        private UIElement BuildSpinner()
        {
            System.Windows.Shapes.Ellipse ring = new System.Windows.Shapes.Ellipse();
            ring.Width = 42;
            ring.Height = 42;
            ring.Stroke = Theme.Cobalt;
            ring.StrokeThickness = 3;
            ring.StrokeDashArray = new DoubleCollection(new double[] { 2.2, 1.4 });
            ring.RenderTransformOrigin = new Point(0.5, 0.5);
            RotateTransform rot = new RotateTransform();
            ring.RenderTransform = rot;
            DoubleAnimation anim = new DoubleAnimation(0, 360, new Duration(TimeSpan.FromSeconds(0.85)));
            anim.RepeatBehavior = RepeatBehavior.Forever;
            rot.BeginAnimation(RotateTransform.AngleProperty, anim);
            return ring;
        }

        private void BuildWash()
        {
            AddWash(0.16, 0.12, 820, 0);
            AddWash(0.78, 0.62, 700, 6);
            AddWash(0.42, 0.38, 960, 11);
            _sky.SizeChanged += delegate { PlaceWash(); };
        }

        private void AddWash(double fx, double fy, double size, int delay)
        {
            System.Windows.Shapes.Ellipse spot = new System.Windows.Shapes.Ellipse();
            spot.Width = size;
            spot.Height = size;
            spot.IsHitTestVisible = false;
            spot.Tag = new Point(fx, fy);
            RadialGradientBrush brush = new RadialGradientBrush();
            brush.GradientStops.Add(new GradientStop(Color.FromArgb(36, 0xC2, 0xC6, 0xCC), 0));
            brush.GradientStops.Add(new GradientStop(Color.FromArgb(14, 0xC2, 0xC6, 0xCC), 0.42));
            brush.GradientStops.Add(new GradientStop(Color.FromArgb(0, 0xC2, 0xC6, 0xCC), 1));
            spot.Fill = brush;
            TranslateTransform drift = new TranslateTransform();
            spot.RenderTransform = drift;
            CubicEase ease = new CubicEase();
            ease.EasingMode = EasingMode.EaseInOut;
            ease.Freeze();
            DoubleAnimation slideX = new DoubleAnimation(-22, 22, TimeSpan.FromSeconds(24));
            slideX.AutoReverse = true;
            slideX.RepeatBehavior = RepeatBehavior.Forever;
            slideX.EasingFunction = ease;
            slideX.BeginTime = TimeSpan.FromSeconds(delay);
            DoubleAnimation slideY = new DoubleAnimation(16, -16, TimeSpan.FromSeconds(29));
            slideY.AutoReverse = true;
            slideY.RepeatBehavior = RepeatBehavior.Forever;
            slideY.EasingFunction = ease;
            slideY.BeginTime = TimeSpan.FromSeconds(delay);
            drift.BeginAnimation(TranslateTransform.XProperty, slideX);
            drift.BeginAnimation(TranslateTransform.YProperty, slideY);
            DoubleAnimation fade = new DoubleAnimation(0.35, 0.7, TimeSpan.FromSeconds(16));
            fade.AutoReverse = true;
            fade.RepeatBehavior = RepeatBehavior.Forever;
            fade.EasingFunction = ease;
            fade.BeginTime = TimeSpan.FromSeconds(delay);
            spot.BeginAnimation(UIElement.OpacityProperty, fade);
            _sky.Children.Add(spot);
        }

        private void PlaceWash()
        {
            double w = _sky.ActualWidth;
            double h = _sky.ActualHeight;
            if (w < 10 || h < 10) return;
            foreach (UIElement child in _sky.Children)
            {
                FrameworkElement el = child as FrameworkElement;
                if (el == null || !(el.Tag is Point)) continue;
                Point p = (Point)el.Tag;
                Canvas.SetLeft(el, p.X * w - el.Width / 2);
                Canvas.SetTop(el, p.Y * h - el.Height / 2);
            }
        }

        private void TickMeters()
        {
            if (_cpu != null)
            {
                try
                {
                    double pct = _cpu.NextValue();
                    SetMeter(_meters[0], pct, ((int)pct).ToString() + "%", Lang.T("uso del procesador", "processor use"));
                }
                catch { SetMeter(_meters[0], 0, "—", Lang.T("sin lectura", "no reading")); }
            }

            MEMORYSTATUSEX mem = new MEMORYSTATUSEX();
            mem.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            if (GlobalMemoryStatusEx(ref mem) && mem.ullTotalPhys > 0)
            {
                double used = (mem.ullTotalPhys - mem.ullAvailPhys) / 1073741824.0;
                double total = mem.ullTotalPhys / 1073741824.0;
                SetMeter(_meters[1], mem.dwMemoryLoad, mem.dwMemoryLoad.ToString() + "%",
                    used.ToString("0.0") + " / " + total.ToString("0.0") + " GB");
            }

            if (_gpuLive || _vram.Count > 0)
            {
                double gpu = _gpuPct;
                if (gpu > 100) gpu = 100;
                string extra = Lang.T("actividad 3D", "3D activity");
                if (_vram.Count > 0)
                {
                    double gb = Sum(_vram) / 1073741824.0;
                    extra = "VRAM " + gb.ToString("0.0") + " GB";
                }
                SetMeter(_meters[2], gpu, ((int)gpu).ToString() + "%", extra);
            }
            else
            {
                SetMeter(_meters[2], 0, "—", Lang.T("sensor no disponible", "sensor unavailable"));
            }

            if (_disk != null)
            {
                try
                {
                    double mb = _disk.NextValue() / 1048576.0;
                    string space = Lang.T("actividad", "activity");
                    try
                    {
                        string root = Path.GetPathRoot(Environment.SystemDirectory);
                        DriveInfo drive = new DriveInfo(root);
                        if (drive.IsReady && drive.TotalSize > 0)
                        {
                            double usedGb = (drive.TotalSize - drive.AvailableFreeSpace) / 1073741824.0;
                            double totalGb = drive.TotalSize / 1073741824.0;
                            space = root.TrimEnd('\\') + "  " + usedGb.ToString("0") + " / " + totalGb.ToString("0") + " GB";
                        }
                    }
                    catch { }
                    SetMeter(_meters[3], LoadPct(mb, 200), mb.ToString("0.0") + " MB/s", space);
                }
                catch { SetMeter(_meters[3], 0, "—", Lang.T("sin lectura", "no reading")); }
            }

            if (_rx.Count > 0 || _tx.Count > 0)
            {
                double downMbps = Sum(_rx) * 8.0 / 1048576.0;
                double upMbps = Sum(_tx) * 8.0 / 1048576.0;
                SetMeter(_meters[4], LoadPct(downMbps, 100),
                    downMbps.ToString("0.0") + " Mb/s",
                    Lang.T("subida ", "up ") + upMbps.ToString("0.0") + " Mb/s");
            }
            else
            {
                SetMeter(_meters[4], 0, "—", Lang.T("sin adaptador", "no adapter"));
            }
        }

        private static double LoadPct(double value, double full)
        {
            if (value < 0 || full <= 0) return 0;
            double pct = value / full * 100.0;
            if (pct > 100) pct = 100;
            return pct;
        }

        private void SampleGpu()
        {
            if (Interlocked.Exchange(ref _gpuBusy, 1) == 1) return;
            try
            {
                RefreshGpuEngines();
                Dictionary<string, double> byEngine = new Dictionary<string, double>();
                List<string> dead = new List<string>();
                bool hadPrev = false;
                foreach (KeyValuePair<string, PerformanceCounter> pair in _gpuEngines)
                {
                    try
                    {
                        CounterSample now = pair.Value.NextSample();
                        CounterSample prev;
                        if (_gpuPrev.TryGetValue(pair.Key, out prev))
                        {
                            hadPrev = true;
                            float pct = CounterSample.Calculate(prev, now);
                            if (float.IsNaN(pct) || float.IsInfinity(pct) || pct < 0) pct = 0;
                            if (pct > 100) pct = 100;
                            string key = EngineKey(pair.Key);
                            double have;
                            if (!byEngine.TryGetValue(key, out have)) have = 0;
                            byEngine[key] = have + pct;
                        }
                        _gpuPrev[pair.Key] = now;
                    }
                    catch { dead.Add(pair.Key); }
                }
                DropGpu(dead);
                if (hadPrev)
                {
                    double max = 0;
                    foreach (KeyValuePair<string, double> item in byEngine)
                    {
                        double capped = item.Value;
                        if (capped > 100) capped = 100;
                        if (capped > max) max = capped;
                    }
                    _gpuPct = max;
                    _gpuLive = true;
                }
            }
            catch { }
            finally { Interlocked.Exchange(ref _gpuBusy, 0); }
        }

        private void RefreshGpuEngines()
        {
            _gpuScan++;
            if (_gpuScan != 1 && _gpuScan % 3 != 0) return;
            string[] names;
            try { names = new PerformanceCounterCategory("GPU Engine").GetInstanceNames(); }
            catch { return; }
            Dictionary<string, bool> live = new Dictionary<string, bool>();
            for (int i = 0; i < names.Length; i++)
            {
                string n = names[i];
                if (n.IndexOf("engtype_3D", StringComparison.OrdinalIgnoreCase) < 0) continue;
                live[n] = true;
                if (_gpuEngines.ContainsKey(n)) continue;
                try { _gpuEngines[n] = new PerformanceCounter("GPU Engine", "Utilization Percentage", n); }
                catch { }
            }
            List<string> gone = new List<string>();
            foreach (KeyValuePair<string, PerformanceCounter> pair in _gpuEngines)
            {
                if (!live.ContainsKey(pair.Key)) gone.Add(pair.Key);
            }
            DropGpu(gone);
        }

        private void DropGpu(List<string> names)
        {
            for (int i = 0; i < names.Count; i++)
            {
                string key = names[i];
                PerformanceCounter pc;
                if (_gpuEngines.TryGetValue(key, out pc))
                {
                    try { pc.Dispose(); } catch { }
                    _gpuEngines.Remove(key);
                }
                _gpuPrev.Remove(key);
            }
        }

        private static string EngineKey(string instance)
        {
            int at = instance.IndexOf("_luid_", StringComparison.Ordinal);
            int end = instance.IndexOf("_engtype_", StringComparison.Ordinal);
            if (at < 0 || end <= at) return instance;
            return instance.Substring(at + 1, end - at - 1);
        }

        private void SetMeter(LiveMeter meter, double pct, string value, string extra)
        {
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
            meter.Value.Text = value;
            meter.Extra.Text = extra;
            DoubleAnimation anim = new DoubleAnimation();
            anim.To = pct / 100.0;
            anim.Duration = new Duration(TimeSpan.FromMilliseconds(620));
            QuadraticEase ease = new QuadraticEase();
            ease.EasingMode = EasingMode.EaseOut;
            anim.EasingFunction = ease;
            meter.Scale.BeginAnimation(ScaleTransform.ScaleXProperty, anim);
            Brush color = Theme.Green;
            if (pct >= 85) color = Theme.Red;
            else if (pct >= 65) color = Theme.Cobalt;
            meter.Fill.Background = color;
            meter.Spark.Stroke = color;
            meter.Area.Fill = Soft(color);
            int last = meter.History.Length - 1;
            for (int i = 0; i < last; i++) meter.History[i] = meter.History[i + 1];
            meter.History[last] = pct;
            DrawSpark(meter);
        }

        private static void DrawSpark(LiveMeter meter)
        {
            double w = meter.Root.ActualWidth - 28;
            if (w < 30) w = 130;
            PointCollection pts = new PointCollection();
            int n = meter.History.Length;
            for (int i = 0; i < n; i++)
            {
                double x = w * i / (n - 1);
                double y = 20 - (meter.History[i] / 100.0) * 18;
                pts.Add(new Point(x, y));
            }
            meter.Spark.Points = pts;
            PointCollection area = new PointCollection();
            area.Add(new Point(0, 36));
            for (int i = 0; i < pts.Count; i++) area.Add(pts[i]);
            area.Add(new Point(w, 36));
            meter.Area.Points = area;
        }

        private static Brush Soft(Brush source)
        {
            SolidColorBrush solid = source as SolidColorBrush;
            if (solid == null) return source;
            return new SolidColorBrush(Color.FromArgb(70, solid.Color.R, solid.Color.G, solid.Color.B));
        }

        private void Reflow()
        {
            if (_scroll == null) return;
            double avail = _scroll.ActualWidth;
            if (avail < 40) return;
            if (_side != null) _side.Width = ActualWidth < 980 ? 196 : 248;
            int cols = 1;
            if (_page != "Soporte")
            {
                if (avail >= 640) cols = 3;
                else if (avail >= 420) cols = 2;
            }
            double gap = 14;
            double cardW = Math.Floor((avail - 24 - (cols * gap)) / cols);
            if (cardW < 150 && cols > 1)
            {
                cols--;
                cardW = Math.Floor((avail - 24 - (cols * gap)) / cols);
            }
            foreach (UIElement el in _cards.Children)
            {
                FrameworkElement fe = el as FrameworkElement;
                if (fe != null) fe.Width = cardW;
            }
            for (int i = 0; i < _meters.Count; i++) DrawSpark(_meters[i]);
        }

        private void AddResizeEdges(Grid host)
        {
            host.Children.Add(ResizeEdge(HorizontalAlignment.Left, VerticalAlignment.Stretch, 7, 0, Cursors.SizeWE, 10));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Right, VerticalAlignment.Stretch, 7, 0, Cursors.SizeWE, 11));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Stretch, VerticalAlignment.Bottom, 0, 7, Cursors.SizeNS, 15));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Left, VerticalAlignment.Top, 14, 14, Cursors.SizeNWSE, 13));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Right, VerticalAlignment.Top, 14, 14, Cursors.SizeNESW, 14));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Left, VerticalAlignment.Bottom, 16, 16, Cursors.SizeNESW, 16));
            host.Children.Add(ResizeEdge(HorizontalAlignment.Right, VerticalAlignment.Bottom, 18, 18, Cursors.SizeNWSE, 17));
        }

        private Border ResizeEdge(HorizontalAlignment h, VerticalAlignment v, double w, double height, Cursor cursor, int hit)
        {
            Border edge = new Border();
            edge.Background = Brushes.Transparent;
            edge.HorizontalAlignment = h;
            edge.VerticalAlignment = v;
            if (w > 0) edge.Width = w;
            if (height > 0) edge.Height = height;
            edge.Cursor = cursor;
            edge.MouseLeftButtonDown += delegate(object s, MouseButtonEventArgs e)
            {
                e.Handled = true;
                BeginResize(hit);
            };
            return edge;
        }

        private void BeginResize(int hit)
        {
            try
            {
                ReleaseCapture();
                System.Windows.Interop.WindowInteropHelper helper = new System.Windows.Interop.WindowInteropHelper(this);
                SendMessage(helper.Handle, 0xA1, new IntPtr(hit), IntPtr.Zero);
            }
            catch { }
        }

        private static void InstallDarkScroll()
        {
            try
            {
            if (Application.Current == null) return;
            if (Application.Current.Resources.Contains(typeof(ScrollBar))) return;
            Style bar = new Style(typeof(ScrollBar));
            bar.Setters.Add(new Setter(Control.BackgroundProperty, Brushes.Transparent));
            bar.Setters.Add(new Setter(Control.TemplateProperty, BarTemplate(true)));
            bar.Setters.Add(new Setter(FrameworkElement.WidthProperty, 8.0));
            Trigger wide = new Trigger();
            wide.Property = ScrollBar.OrientationProperty;
            wide.Value = Orientation.Horizontal;
            wide.Setters.Add(new Setter(Control.TemplateProperty, BarTemplate(false)));
            wide.Setters.Add(new Setter(FrameworkElement.WidthProperty, double.NaN));
            wide.Setters.Add(new Setter(FrameworkElement.HeightProperty, 8.0));
            bar.Triggers.Add(wide);
            Application.Current.Resources.Add(typeof(ScrollBar), bar);

            Style viewer = new Style(typeof(ScrollViewer));
            viewer.Setters.Add(new Setter(Control.BackgroundProperty, Brushes.Transparent));
            viewer.Setters.Add(new Setter(Control.TemplateProperty, ViewerTemplate()));
            Application.Current.Resources.Add(typeof(ScrollViewer), viewer);
            }
            catch { }
        }

        private static ControlTemplate BarTemplate(bool vertical)
        {
            string reversed = vertical ? " IsDirectionReversed='True'" : "";
            string up = vertical ? "ScrollBar.PageUpCommand" : "ScrollBar.PageLeftCommand";
            string down = vertical ? "ScrollBar.PageDownCommand" : "ScrollBar.PageRightCommand";
            string xaml =
                "<ControlTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' " +
                "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' TargetType='ScrollBar'>" +
                "<Grid Background='Transparent'>" +
                "<Track x:Name='PART_Track'" + reversed + ">" +
                "<Track.DecreaseRepeatButton><RepeatButton Command='" + up + "' Opacity='0' Focusable='False'/></Track.DecreaseRepeatButton>" +
                "<Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType='Thumb'>" +
                "<Border Background='#6A6E76' CornerRadius='4' Margin='1'/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>" +
                "<Track.IncreaseRepeatButton><RepeatButton Command='" + down + "' Opacity='0' Focusable='False'/></Track.IncreaseRepeatButton>" +
                "</Track></Grid></ControlTemplate>";
            return (ControlTemplate)System.Windows.Markup.XamlReader.Parse(xaml);
        }

        private static ControlTemplate ViewerTemplate()
        {
            string xaml =
                "<ControlTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' " +
                "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' TargetType='ScrollViewer'>" +
                "<Grid Background='Transparent'>" +
                "<Grid.ColumnDefinitions><ColumnDefinition Width='*'/><ColumnDefinition Width='Auto'/></Grid.ColumnDefinitions>" +
                "<Grid.RowDefinitions><RowDefinition Height='*'/><RowDefinition Height='Auto'/></Grid.RowDefinitions>" +
                "<ScrollContentPresenter x:Name='PART_ScrollContentPresenter' Grid.Row='0' Grid.Column='0' " +
                "CanContentScroll='{TemplateBinding CanContentScroll}' Content='{TemplateBinding Content}'/>" +
                "<ScrollBar x:Name='PART_VerticalScrollBar' Grid.Row='0' Grid.Column='1' Orientation='Vertical' " +
                "Maximum='{TemplateBinding ScrollableHeight}' ViewportSize='{TemplateBinding ViewportHeight}' " +
                "Value='{TemplateBinding VerticalOffset}' Visibility='{TemplateBinding ComputedVerticalScrollBarVisibility}'/>" +
                "<ScrollBar x:Name='PART_HorizontalScrollBar' Grid.Row='1' Grid.Column='0' Orientation='Horizontal' " +
                "Maximum='{TemplateBinding ScrollableWidth}' ViewportSize='{TemplateBinding ViewportWidth}' " +
                "Value='{TemplateBinding HorizontalOffset}' Visibility='{TemplateBinding ComputedHorizontalScrollBarVisibility}'/>" +
                "<Border Grid.Row='1' Grid.Column='1' Background='#0A0A0E'/>" +
                "</Grid></ControlTemplate>";
            return (ControlTemplate)System.Windows.Markup.XamlReader.Parse(xaml);
        }

        private void ToggleLive()
        {
            if (_busyFlag) return;
            _live = !_live;
            PaintMode();
            Append(_live ? Lang.T("Modo real activado. Los cambios sí se aplican.", "Live mode on. Changes will be applied.") : Lang.T("Modo prueba activado. Nada se modifica.", "Test mode on. Nothing is changed."));
        }

        private UIElement BuildModeSwitch()
        {
            _modeButton = new Border();
            _modeButton.Margin = new Thickness(0, 14, 0, 0);
            _modeButton.Padding = new Thickness(10, 8, 10, 8);
            _modeButton.CornerRadius = new CornerRadius(8);
            _modeButton.BorderBrush = Theme.LineStrong;
            _modeButton.BorderThickness = new Thickness(1);
            _modeButton.Background = Brushes.Transparent;
            _modeButton.Cursor = Cursors.Hand;
            _modeButtonText = new TextBlock();
            _modeButtonText.FontSize = 13;
            _modeButtonText.FontWeight = FontWeights.SemiBold;
            _modeButtonText.HorizontalAlignment = HorizontalAlignment.Center;
            _modeButton.Child = _modeButtonText;
            _modeButton.MouseEnter += delegate { _modeButton.Background = Theme.Card2; };
            _modeButton.MouseLeave += delegate { _modeButton.Background = Brushes.Transparent; };
            _modeButton.MouseLeftButtonUp += delegate { ToggleLive(); };

            _modeTestTitle = new TextBlock();
            _modeLiveTitle = new TextBlock();
            _modeTestRow = ModeLine(_modeTestTitle, Lang.T("Prueba", "Test"), Lang.T("Nada se modifica.", "Nothing is changed."));
            _modeLiveRow = ModeLine(_modeLiveTitle, Lang.T("Real", "Live"), Lang.T("Los cambios sí se aplican.", "Changes will be applied."));
            _modeLiveRow.Margin = new Thickness(0, 8, 0, 0);

            TextBlock cap = new TextBlock();
            cap.Text = Lang.T("MODO", "MODE");
            cap.Foreground = Theme.Faint;
            cap.FontSize = 11;
            cap.Margin = new Thickness(2, 0, 0, 10);

            StackPanel body = new StackPanel();
            body.Children.Add(cap);
            body.Children.Add(_modeTestRow);
            body.Children.Add(_modeLiveRow);
            body.Children.Add(_modeButton);

            Border section = new Border();
            section.Margin = new Thickness(12, 18, 12, 8);
            section.Padding = new Thickness(12, 12, 12, 14);
            section.CornerRadius = new CornerRadius(12);
            section.Background = Theme.Bg;
            section.BorderBrush = Theme.LineStrong;
            section.BorderThickness = new Thickness(1);
            section.Child = body;
            return section;
        }

        private static Border ModeLine(TextBlock title, string name, string hint)
        {
            title.Text = name;
            title.FontSize = 14;
            title.FontWeight = FontWeights.SemiBold;
            TextBlock line = new TextBlock();
            line.Text = hint;
            line.FontSize = 12;
            line.Foreground = Theme.Muted;
            line.TextWrapping = TextWrapping.Wrap;
            line.Margin = new Thickness(0, 2, 0, 0);
            StackPanel text = new StackPanel();
            text.Children.Add(title);
            text.Children.Add(line);
            Border row = new Border();
            row.CornerRadius = new CornerRadius(8);
            row.Padding = new Thickness(10, 8, 10, 8);
            row.Child = text;
            return row;
        }

        private void PaintMode()
        {
            _modeButtonText.Text = _live ? Lang.T("Volver a prueba", "Back to test") : Lang.T("Pasar a real", "Switch to live");
            _modeButtonText.Foreground = _live ? Theme.Text : Theme.Red;
            _modeTestRow.Background = _live ? Brushes.Transparent : Theme.Card2;
            _modeLiveRow.Background = _live ? Theme.RedSoft : Brushes.Transparent;
            _modeTestTitle.Foreground = _live ? Theme.Faint : Theme.Text;
            _modeLiveTitle.Foreground = _live ? Theme.Red : Theme.Faint;
        }

        private UIElement BuildLogo()
        {
            StackPanel lights = new StackPanel();
            lights.Orientation = Orientation.Horizontal;
            lights.VerticalAlignment = VerticalAlignment.Center;
            Action playYellow, stopYellow, playGreen, stopGreen, playRed, stopRed;
            lights.Children.Add(LogoDot(0xFE, 0xBC, 0x2E, 0, out playYellow, out stopYellow));
            lights.Children.Add(LogoDot(0x28, 0xC8, 0x40, 160, out playGreen, out stopGreen));
            lights.Children.Add(LogoDot(0xFF, 0x5F, 0x57, 320, out playRed, out stopRed));
            Border zone = new Border();
            zone.Background = Brushes.Transparent;
            zone.Padding = new Thickness(2, 10, 2, 10);
            zone.Margin = new Thickness(0, 0, 10, 0);
            zone.VerticalAlignment = VerticalAlignment.Center;
            zone.Child = lights;
            zone.MouseEnter += delegate { playYellow(); playGreen(); playRed(); };
            zone.MouseLeave += delegate { stopYellow(); stopGreen(); stopRed(); };

            Typeface face = new Typeface(Theme.Display, FontStyles.Normal, FontWeights.Black, FontStretches.Normal);
            FormattedText text = new FormattedText("Game Fixer", CultureInfo.CurrentCulture, FlowDirection.LeftToRight, face, 24, Brushes.White, 1.0);
            System.Windows.Shapes.Path letters = new System.Windows.Shapes.Path();
            letters.Data = text.BuildGeometry(new Point(0, 0));
            letters.Fill = Brushes.White;
            letters.Stroke = Theme.Green;
            letters.StrokeThickness = 0.7;
            letters.StrokeLineJoin = PenLineJoin.Round;
            letters.VerticalAlignment = VerticalAlignment.Center;
            DropShadowEffect neon = new DropShadowEffect();
            neon.Color = Color.FromRgb(0x3D, 0xDC, 0x84);
            neon.BlurRadius = 7;
            neon.ShadowDepth = 0;
            neon.Opacity = 0.9;
            letters.Effect = neon;

            StackPanel row = new StackPanel();
            row.Orientation = Orientation.Horizontal;
            row.Margin = new Thickness(16, 20, 12, 12);
            row.Children.Add(zone);
            row.Children.Add(letters);
            return row;
        }

        private static UIElement LogoDot(byte r, byte g, byte b, int phase, out Action play, out Action stop)
        {
            Grid host = new Grid();
            host.Width = 14;
            host.Height = 14;
            host.VerticalAlignment = VerticalAlignment.Center;
            host.IsHitTestVisible = false;

            ScaleTransform[] scales = new ScaleTransform[3];
            System.Windows.Shapes.Ellipse[] rings = new System.Windows.Shapes.Ellipse[3];
            for (int i = 0; i < 3; i++)
            {
                System.Windows.Shapes.Ellipse ring = new System.Windows.Shapes.Ellipse();
                ring.Width = 8;
                ring.Height = 8;
                ring.HorizontalAlignment = HorizontalAlignment.Center;
                ring.VerticalAlignment = VerticalAlignment.Center;
                ring.IsHitTestVisible = false;
                ring.Opacity = 0;
                ring.StrokeThickness = 1;
                ring.Stroke = new SolidColorBrush(Color.FromArgb((byte)(170 - i * 40), r, g, b));
                ring.Fill = new SolidColorBrush(Color.FromArgb((byte)(36 - i * 8), r, g, b));
                ScaleTransform scale = new ScaleTransform(1, 1);
                ring.RenderTransform = scale;
                ring.RenderTransformOrigin = new Point(0.5, 0.5);
                rings[i] = ring;
                scales[i] = scale;
                host.Children.Add(ring);
            }

            System.Windows.Shapes.Ellipse core = new System.Windows.Shapes.Ellipse();
            core.Width = 8;
            core.Height = 8;
            core.HorizontalAlignment = HorizontalAlignment.Center;
            core.VerticalAlignment = VerticalAlignment.Center;
            core.IsHitTestVisible = false;
            core.Fill = new SolidColorBrush(Color.FromRgb(r, g, b));
            ScaleTransform coreScale = new ScaleTransform(1, 1);
            core.RenderTransform = coreScale;
            core.RenderTransformOrigin = new Point(0.5, 0.5);
            host.Children.Add(core);

            CubicEase ease = new CubicEase();
            ease.EasingMode = EasingMode.EaseInOut;
            ease.Freeze();
            play = delegate
            {
                DoubleAnimation coreX = new DoubleAnimation(1, 1.22, TimeSpan.FromMilliseconds(700));
                coreX.AutoReverse = true;
                coreX.RepeatBehavior = RepeatBehavior.Forever;
                coreX.EasingFunction = ease;
                coreX.BeginTime = TimeSpan.FromMilliseconds(phase);
                coreScale.BeginAnimation(ScaleTransform.ScaleXProperty, coreX);
                coreScale.BeginAnimation(ScaleTransform.ScaleYProperty, coreX.Clone());
                for (int i = 0; i < 3; i++)
                {
                    int at = phase + (140 * i);
                    DoubleAnimation fade = new DoubleAnimation(0.2, 0.85, TimeSpan.FromMilliseconds(700));
                    fade.AutoReverse = true;
                    fade.RepeatBehavior = RepeatBehavior.Forever;
                    fade.EasingFunction = ease;
                    fade.BeginTime = TimeSpan.FromMilliseconds(at);
                    rings[i].BeginAnimation(UIElement.OpacityProperty, fade);
                    DoubleAnimation grow = new DoubleAnimation(1, 2.05, TimeSpan.FromMilliseconds(700));
                    grow.AutoReverse = true;
                    grow.RepeatBehavior = RepeatBehavior.Forever;
                    grow.EasingFunction = ease;
                    grow.BeginTime = TimeSpan.FromMilliseconds(at);
                    scales[i].BeginAnimation(ScaleTransform.ScaleXProperty, grow);
                    scales[i].BeginAnimation(ScaleTransform.ScaleYProperty, grow.Clone());
                }
            };
            stop = delegate
            {
                coreScale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
                coreScale.BeginAnimation(ScaleTransform.ScaleYProperty, null);
                coreScale.ScaleX = 1;
                coreScale.ScaleY = 1;
                for (int i = 0; i < 3; i++)
                {
                    scales[i].BeginAnimation(ScaleTransform.ScaleXProperty, null);
                    scales[i].BeginAnimation(ScaleTransform.ScaleYProperty, null);
                    scales[i].ScaleX = 1;
                    scales[i].ScaleY = 1;
                    DoubleAnimation fade = new DoubleAnimation(0, TimeSpan.FromMilliseconds(140));
                    rings[i].BeginAnimation(UIElement.OpacityProperty, fade);
                }
            };
            return host;
        }

        private void StartGlow(Border frame)
        {
            StopGlow();
            System.Windows.Shapes.Ellipse blob = frame.Tag as System.Windows.Shapes.Ellipse;
            Grid layers = frame.Child as Grid;
            Border card = layers == null ? null : layers.Children[1] as Border;
            if (blob == null || card == null) return;
            _glowFrame = frame;
            _glowCard = card;
            _glowBlob = blob;
            _glowInk = blob.Fill as SolidColorBrush;
            _glowTravel = 0;
            blob.Opacity = 1;
            card.Margin = new Thickness(3);
            if (_glowTimer == null)
            {
                _glowTimer = new DispatcherTimer();
                _glowTimer.Interval = TimeSpan.FromMilliseconds(16);
                _glowTimer.Tick += delegate { MoveGlow(); };
            }
            _glowTimer.Start();
        }

        private void StopGlow()
        {
            if (_glowTimer != null) _glowTimer.Stop();
            if (_glowBlob != null) _glowBlob.Opacity = 0;
            if (_glowCard != null) _glowCard.Margin = new Thickness(0);
            _glowFrame = null;
            _glowCard = null;
            _glowBlob = null;
            _glowInk = null;
        }

        private void MoveGlow()
        {
            if (_glowFrame == null || _glowBlob == null) return;
            double w = _glowFrame.ActualWidth;
            double h = _glowFrame.ActualHeight;
            if (w < 8 || h < 8) return;
            _glowTravel += 5.5;
            double lap = (w + h) * 2;
            double d = _glowTravel % lap;
            double x;
            double y;
            if (d < w) { x = d; y = 0; }
            else if (d < w + h) { x = w; y = d - w; }
            else if (d < w + h + w) { x = w - (d - w - h); y = h; }
            else { x = 0; y = h - (d - (2 * w + h)); }
            Canvas.SetLeft(_glowBlob, x - _glowBlob.Width / 2);
            Canvas.SetTop(_glowBlob, y - _glowBlob.Height / 2);
            if (_glowInk == null) return;
            double t = (_glowTravel / 220.0) % 3.0;
            Color yellow = Color.FromRgb(0xFE, 0xBC, 0x2E);
            Color green = Color.FromRgb(0x28, 0xC8, 0x40);
            Color red = Color.FromRgb(0xFF, 0x5F, 0x57);
            if (t < 1) _glowInk.Color = Mix(yellow, green, t);
            else if (t < 2) _glowInk.Color = Mix(green, red, t - 1);
            else _glowInk.Color = Mix(red, yellow, t - 2);
        }

        private static Color Mix(Color a, Color b, double t)
        {
            if (t < 0) t = 0;
            if (t > 1) t = 1;
            return Color.FromRgb(
                (byte)(a.R + (b.R - a.R) * t),
                (byte)(a.G + (b.G - a.G) * t),
                (byte)(a.B + (b.B - a.B) * t));
        }

        private static TextBox CodeBox()
        {
            TextBox box = new TextBox();
            box.IsReadOnly = true;
            box.IsReadOnlyCaretVisible = true;
            box.BorderThickness = new Thickness(0);
            box.Background = Brushes.Transparent;
            box.Foreground = Brushes.White;
            box.CaretBrush = Brushes.White;
            box.FontFamily = new FontFamily("Consolas");
            box.FontSize = 32;
            box.FontWeight = FontWeights.Black;
            box.Padding = new Thickness(0);
            box.MinHeight = 42;
            return box;
        }

        private UIElement BuildSupport()
        {
            _pageCodeCard = new Border();
            _pageCodeCard.Background = Theme.Bg;
            _pageCodeCard.BorderBrush = Theme.Green;
            _pageCodeCard.BorderThickness = new Thickness(1);
            _pageCodeCard.CornerRadius = new CornerRadius(12);
            _pageCodeCard.Padding = new Thickness(16, 14, 16, 14);
            _pageCodeCard.Margin = new Thickness(0, 0, 0, 16);
            _pageCodeCard.Visibility = string.IsNullOrEmpty(_supportCode) ? Visibility.Collapsed : Visibility.Visible;
            DockPanel pageRow = new DockPanel();
            _pageCodeCard.Child = pageRow;
            Border pageCopy = new Border();
            pageCopy.Background = Theme.Card2;
            pageCopy.BorderBrush = Theme.LineStrong;
            pageCopy.BorderThickness = new Thickness(1);
            pageCopy.CornerRadius = new CornerRadius(8);
            pageCopy.Padding = new Thickness(14, 8, 14, 8);
            pageCopy.Cursor = Cursors.Hand;
            pageCopy.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(pageCopy, Dock.Right);
            TextBlock pageCopyText = new TextBlock();
            pageCopyText.Text = Lang.T("Copiar", "Copy");
            pageCopyText.Foreground = Theme.Text;
            pageCopyText.FontWeight = FontWeights.SemiBold;
            pageCopyText.FontSize = 14;
            _pageCopyLabel = pageCopyText;
            pageCopy.Child = pageCopyText;
            pageCopy.MouseLeftButtonUp += delegate { CopySupportCode(); };
            pageRow.Children.Add(pageCopy);
            StackPanel pageText = new StackPanel();
            pageRow.Children.Add(pageText);
            TextBlock pageCap = new TextBlock();
            pageCap.Text = Lang.T("CÓDIGO PARA EL SOPORTE", "CODE FOR SUPPORT");
            pageCap.Foreground = Theme.Faint;
            pageCap.FontSize = 11;
            pageText.Children.Add(pageCap);
            _pageCodeText = CodeBox();
            _pageCodeText.Text = _supportCode == null ? "" : _supportCode;
            _pageCodeText.Margin = new Thickness(0, 4, 12, 0);
            pageText.Children.Add(_pageCodeText);
            TextBlock pageHint = new TextBlock();
            pageHint.Text = Lang.T("Cópialo y envíalo para revisar el informe.", "Copy it and send it so the report can be reviewed.");
            pageHint.Foreground = Theme.Muted;
            pageHint.FontSize = 13;
            pageHint.Margin = new Thickness(0, 6, 12, 0);
            pageText.Children.Add(pageHint);

            TextBlock explain = new TextBlock();
            explain.Text = Lang.T(
                "El informe incluye hardware, Windows, drivers, red, eventos recientes y un diagnóstico. No envía tu nombre, el nombre del PC, la IP, las direcciones MAC ni contraseñas.",
                "The report includes hardware, Windows, drivers, network, recent events and a diagnosis. It does not send your name, PC name, IP, MAC addresses or passwords.");
            explain.Foreground = Theme.Muted;
            explain.FontSize = 14;
            explain.TextWrapping = TextWrapping.Wrap;

            TextBlock label = new TextBlock();
            label.Text = Lang.T("Nota opcional", "Optional note");
            label.Foreground = Theme.Text;
            label.FontSize = 15;
            label.FontWeight = FontWeights.SemiBold;
            label.Margin = new Thickness(0, 18, 0, 8);

            Grid field = new Grid();
            field.MinHeight = 120;
            TextBox note = new TextBox();
            note.AcceptsReturn = true;
            note.TextWrapping = TextWrapping.Wrap;
            note.MinHeight = 120;
            note.MaxLength = 1800;
            note.Background = Theme.Card2;
            note.Foreground = Brushes.White;
            note.BorderBrush = Theme.LineStrong;
            note.BorderThickness = new Thickness(1);
            note.Padding = new Thickness(12, 10, 12, 10);
            note.FontSize = 15;
            note.CaretBrush = Brushes.White;
            TextBlock hint = new TextBlock();
            hint.Text = Lang.T("Escribe aquí qué te pasa. Si lo dejas vacío, el informe se envía igual.", "Write what is happening. If you leave it empty, the report is still sent.");
            hint.Foreground = Theme.Faint;
            hint.FontSize = 15;
            hint.TextWrapping = TextWrapping.Wrap;
            hint.Margin = new Thickness(14, 12, 14, 0);
            hint.IsHitTestVisible = false;
            hint.VerticalAlignment = VerticalAlignment.Top;
            note.TextChanged += delegate
            {
                hint.Visibility = string.IsNullOrEmpty(note.Text) ? Visibility.Visible : Visibility.Collapsed;
            };
            note.GotFocus += delegate { note.BorderBrush = Theme.Green; };
            note.LostFocus += delegate { note.BorderBrush = Theme.LineStrong; };
            field.Children.Add(note);
            field.Children.Add(hint);

            Border send = new Border();
            send.Margin = new Thickness(0, 16, 0, 0);
            send.Padding = new Thickness(18, 10, 18, 10);
            send.CornerRadius = new CornerRadius(8);
            send.Background = Theme.Green;
            send.HorizontalAlignment = HorizontalAlignment.Left;
            send.Cursor = Cursors.Hand;
            TextBlock sendText = new TextBlock();
            sendText.Text = Lang.T("Enviar informe", "Send report");
            sendText.Foreground = Theme.Bg;
            sendText.FontSize = 15;
            sendText.FontWeight = FontWeights.Bold;
            send.Child = sendText;
            send.MouseEnter += delegate { send.Opacity = 0.85; };
            send.MouseLeave += delegate { send.Opacity = 1; };
            send.MouseLeftButtonUp += delegate
            {
                if (_busyFlag) return;
                string ask = Lang.T(
                    "Se enviará el informe de este equipo al soporte.\n\n¿Enviar?",
                    "This PC report will be sent to support.\n\nSend?");
                if (MessageBox.Show(this, ask, "Game Fixer", MessageBoxButton.OKCancel, MessageBoxImage.Information) != MessageBoxResult.OK)
                    return;
                _supportPending = note.Text == null ? "" : note.Text.Trim();
                Act act = new Act();
                act.Page = "Soporte";
                act.Id = "soporte";
                act.Title = Lang.T("Informe de soporte", "Support report");
                act.Detail = Lang.T("Estamos reuniendo los datos del equipo.", "Gathering this PC's details.");
                act.Confirm = false;
                Run(act, new Border());
            };

            StackPanel stack = new StackPanel();
            stack.Children.Add(_pageCodeCard);
            stack.Children.Add(explain);
            stack.Children.Add(label);
            stack.Children.Add(field);
            stack.Children.Add(send);

            Border card = new Border();
            card.Background = Theme.Card;
            card.BorderBrush = Theme.Line;
            card.BorderThickness = new Thickness(1);
            card.CornerRadius = new CornerRadius(12);
            card.Padding = new Thickness(18, 16, 18, 16);
            card.Child = stack;
            return card;
        }

        private void ShowPage(Act[] acts)
        {
            StopGlow();
            _pageTitle.Text = Lang.Page(_page);
            if (_lead != null)
            {
                if (_page == "Soporte")
                    _lead.Text = Lang.T("Escribe una nota si quieres y envía el informe. El código sale grande para copiarlo.", "Add a note if you want and send the report. The code appears large so you can copy it.");
                else
                    _lead.Text = Lang.T("Pulsa una tarjeta. Abajo te diremos qué hace y si tu PC cambió.", "Click a card. Below you'll see what it does and whether your PC changed.");
            }
            _cards.Children.Clear();
            if (_foundHost != null)
            {
                bool showFound = _page == "Juegos" && _foundWrap != null && (_foundWrap.Children.Count > 0 || (_busyFlag && _actId == "juegos"));
                _foundHost.Visibility = showFound ? Visibility.Visible : Visibility.Collapsed;
            }
            if (_startupHost != null)
            {
                bool showStart = _page == "Reparar" && _startupWrap != null && (_startupWrap.Children.Count > 0 || (_busyFlag && _actId == "startup"));
                _startupHost.Visibility = showStart ? Visibility.Visible : Visibility.Collapsed;
            }
            if (_historyHost != null) _historyHost.Visibility = Visibility.Collapsed;
            if (_benchHost != null) _benchHost.Visibility = Visibility.Collapsed;
            if (_page == "Inicio") PaintHistory();
            if (_page == "Medir") PaintBench();
            if (_page == "Soporte")
            {
                _cards.Children.Add(BuildSupport());
                Reflow();
                return;
            }
            for (int i = 0; i < acts.Length; i++)
            {
                if (acts[i].Page != _page) continue;
                _cards.Children.Add(Card(acts[i]));
            }
            Reflow();
            Dispatcher.BeginInvoke(new Action(Reflow), System.Windows.Threading.DispatcherPriority.Loaded);
        }

        private static Border NoteHost(string caption, bool chips, out TextBlock title, out Panel body)
        {
            Border host = new Border();
            host.Visibility = Visibility.Collapsed;
            host.Background = Theme.Card;
            host.BorderBrush = Theme.Line;
            host.BorderThickness = new Thickness(1);
            host.CornerRadius = new CornerRadius(12);
            host.Padding = new Thickness(14, 12, 14, 12);
            host.Margin = new Thickness(0, 0, 14, 14);
            StackPanel stack = new StackPanel();
            host.Child = stack;
            title = new TextBlock();
            title.Text = caption;
            title.Foreground = Theme.Text;
            title.FontSize = 16;
            title.FontWeight = FontWeights.SemiBold;
            stack.Children.Add(title);
            if (chips)
            {
                WrapPanel wrap = new WrapPanel();
                wrap.Margin = new Thickness(0, 10, 0, 0);
                stack.Children.Add(wrap);
                body = wrap;
            }
            else
            {
                StackPanel list = new StackPanel();
                list.Margin = new Thickness(0, 8, 0, 0);
                stack.Children.Add(list);
                body = list;
            }
            return host;
        }

        private Border Card(Act act)
        {
            Border card = new Border();
            card.Background = CardBrush();
            card.BorderBrush = Theme.Line;
            card.BorderThickness = new Thickness(1);
            card.CornerRadius = new CornerRadius(12);
            card.Padding = new Thickness(18, 16, 18, 16);
            card.Cursor = Cursors.Hand;

            DockPanel row = new DockPanel();
            card.Child = row;
            Color iconCool = Color.FromRgb(0x8E, 0x93, 0x9A);
            Color iconHot = CardHot(act.Id);
            SolidColorBrush iconBrush = new SolidColorBrush(iconCool);
            TextBlock icon = new TextBlock();
            icon.FontFamily = new FontFamily("Segoe MDL2 Assets");
            icon.Text = CardGlyph(act.Id);
            icon.FontSize = 18;
            icon.Foreground = iconBrush;
            icon.HorizontalAlignment = HorizontalAlignment.Center;
            icon.VerticalAlignment = VerticalAlignment.Center;
            Border badge = new Border();
            badge.Width = 36;
            badge.Height = 36;
            badge.CornerRadius = new CornerRadius(10);
            badge.Background = Theme.Bg;
            badge.Child = icon;
            badge.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(badge, Dock.Right);
            row.Children.Add(badge);

            StackPanel text = new StackPanel();
            row.Children.Add(text);
            TextBlock title = new TextBlock();
            title.Text = act.Title;
            title.Foreground = Theme.Text;
            title.FontFamily = Theme.Display;
            title.FontSize = 18;
            title.FontWeight = FontWeights.SemiBold;
            text.Children.Add(title);
            TextBlock detail = new TextBlock();
            detail.Text = act.Detail;
            detail.Foreground = Theme.Muted;
            detail.FontSize = 12;
            detail.Margin = new Thickness(0, 2, 12, 0);
            text.Children.Add(detail);

            System.Windows.Shapes.Ellipse blob = new System.Windows.Shapes.Ellipse();
            blob.Width = 92;
            blob.Height = 92;
            blob.Opacity = 0;
            blob.IsHitTestVisible = false;
            SolidColorBrush ink = new SolidColorBrush(Color.FromRgb(0xFF, 0x5F, 0x57));
            blob.Fill = ink;
            blob.Effect = new BlurEffect { Radius = 18 };
            Canvas orbit = new Canvas();
            orbit.IsHitTestVisible = false;
            orbit.Children.Add(blob);

            Grid layers = new Grid();
            layers.Children.Add(orbit);
            layers.Children.Add(card);

            Border frame = new Border();
            frame.CornerRadius = new CornerRadius(14);
            frame.Background = Brushes.Transparent;
            frame.Margin = new Thickness(0, 0, 14, 14);
            frame.Child = layers;
            frame.Tag = blob;
            frame.SizeChanged += delegate
            {
                frame.Clip = new RectangleGeometry(new Rect(0, 0, frame.ActualWidth, frame.ActualHeight), 14, 14);
            };

            card.MouseEnter += delegate
            {
                card.BorderBrush = Theme.LineStrong;
                card.Background = Theme.Card2;
                iconBrush.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(iconHot, TimeSpan.FromMilliseconds(160)));
            };
            card.MouseLeave += delegate
            {
                iconBrush.BeginAnimation(SolidColorBrush.ColorProperty, new ColorAnimation(iconCool, TimeSpan.FromMilliseconds(180)));
                if (_glowCard == card) return;
                card.BorderBrush = Theme.Line;
                card.Background = CardBrush();
            };
            card.MouseLeftButtonUp += delegate { Run(act, frame); };
            return frame;
        }

        private static string CardGlyph(string id)
        {
            if (id != null && id.StartsWith("tweak:")) return "\uE90F";
            switch (id)
            {
                case "diagnostico": return "\uE9D9";
                case "salud": return "\uEA18";
                case "autodiag": return "\uE9F5";
                case "autofix": return "\uE90F";
                case "optimizar": return "\uEC4A";
                case "limpieza": return "\uE74D";
                case "papelera": return "\uE74D";
                case "winsxs": return "\uE8B7";
                case "sfc": return "\uE73E";
                case "dism": return "\uE90F";
                case "reparar": return "\uEA18";
                case "chkdsk": return "\uEDA2";
                case "stutter": return "\uEC4A";
                case "audio": return "\uE767";
                case "inputlag": return "\uE765";
                case "hags": return "\uE950";
                case "mouse": return "\uE962";
                case "restorepoint": return "\uE81C";
                case "backups": return "\uE74E";
                case "rollback": return "\uE7A7";
                case "juegos": return "\uE7FC";
                case "gpuinfo": return "\uE946";
                case "gpudriver": return "\uE72C";
                case "shaders": return "\uE790";
                case "gpuperf": return "\uEC4A";
                case "perfil-gamer": return "\uE7FC";
                case "perfil-streaming": return "\uE714";
                case "perfil-oficina": return "\uE8A5";
                case "perfil-ahorro": return "\uE8BE";
                case "plugins": return "\uEA86";
                case "latencia": return "\uE916";
                case "conexiones": return "\uE701";
                case "dns-cf": return "\uE774";
                case "dns-google": return "\uE774";
                case "dns-reset": return "\uE72C";
                case "resetred": return "\uE839";
                case "startup": return "\uE7E8";
                case "bench-cpu": return "\uE950";
                case "bench-ram": return "\uE7F4";
                case "bench-disk": return "\uEDA2";
                case "bench-net": return "\uE701";
                case "bench-full": return "\uE9D2";
                default: return "\uE946";
            }
        }

        private static Color CardHot(string id)
        {
            if (id != null && id.StartsWith("tweak:")) return Color.FromRgb(0x3D, 0xDC, 0x84);
            switch (id)
            {
                case "limpieza":
                case "papelera":
                case "winsxs":
                case "chkdsk":
                case "rollback":
                case "startup":
                    return Color.FromRgb(0xFE, 0xBC, 0x2E);
                case "latencia":
                case "conexiones":
                case "dns-cf":
                case "dns-google":
                case "dns-reset":
                case "resetred":
                case "gpuinfo":
                case "gpudriver":
                case "autodiag":
                case "bench-full":
                    return Color.FromRgb(0x4C, 0x8D, 0xFF);
                default:
                    return Color.FromRgb(0x3D, 0xDC, 0x84);
            }
        }

        private void Run(Act act, Border frame)
        {
            if (_busyFlag) return;
            bool confirm = act.Confirm && (_live || act.Id == "autofix");
            if (confirm)
            {
                string msg = _live
                    ? Lang.T("Esto modifica el sistema de verdad.\n\n", "This really changes the system.\n\n") + act.Title
                    : Lang.T("Modo prueba: simula esto y no cambia el PC.\n\n", "Test mode: this is only simulated and the PC does not change.\n\n") + act.Title;
                if (MessageBox.Show(this, msg, "Game Fixer", MessageBoxButton.OKCancel, MessageBoxImage.Warning) != MessageBoxResult.OK)
                    return;
            }

            string root = ResolveRoot();
            string script = Path.Combine(root, "GameFixer.ps1");
            if (!File.Exists(script))
            {
                Append(Lang.T("No está GameFixer.ps1 en ", "GameFixer.ps1 was not found in ") + root);
                return;
            }

            StringBuilder args = new StringBuilder();
            args.Append("-NoProfile -ExecutionPolicy Bypass -File \"");
            args.Append(script);
            args.Append("\" -NoBanner -NoUpdate -Action \"");
            args.Append(act.Id);
            args.Append("\"");
            if (_live) args.Append(" -Live");
            if (act.Id == "autofix") args.Append(" -Confirm");

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = args.ToString();
            psi.WorkingDirectory = root;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;
            if (act.Id == "soporte")
            {
                string note = _supportPending == null ? "" : _supportPending;
                psi.EnvironmentVariables["GF_SUPPORT_NOTE"] = note;
            }

            _busyFlag = true;
            _actId = act.Id;
            _actTitle = act.Title;
            _resultLead = null;
            if (_driverLink != null) _driverLink.Visibility = Visibility.Collapsed;
            _driverUrl = null;
            if (act.Id == "juegos") ClearFoundGames();
            if (act.Id == "startup") ClearStartup();
            _sawProblem = false;
            _sawFinding = false;
            _sawResult = false;
            _lastConfirm = act.Confirm;
            _exitCode = 0;
            _steps.Children.Clear();
            _statusTitle.Foreground = Theme.Text;
            _statusTitle.Text = act.Title;
            string doing = Lang.T(" Solo revisa el equipo. No cambia nada.", " This only checks the PC. It changes nothing.");
            if (act.Confirm && _live) doing = Lang.T(" Se va a aplicar en tu PC.", " This will be applied on your PC.");
            else if (act.Confirm) doing = Lang.T(" Modo prueba: muestra qué haría, sin cambiar nada.", " Test mode: shows what it would do, without changing anything.");
            _statusBody.Text = act.Detail + doing;
            Note(Lang.T("Empezando. Puedes seguir viendo esta explicación.", "Starting. You can keep reading this explanation."));
            StartGlow(frame);
            StartProgress();
            Append("");
            Append("> " + act.Title);

            try
            {
                _proc = Process.Start(psi);
            }
            catch (Exception ex)
            {
                _busyFlag = false;
                StopGlow();
                StopProgress();
                if (_barFill != null) _barFill.Background = Theme.Red;
                if (_pctLabel != null) _pctLabel.Foreground = Theme.Red;
                _statusTitle.Text = Lang.T("No se pudo empezar", "Could not start");
                _statusTitle.Foreground = Theme.Red;
                _statusBody.Text = ex.Message;
                Remember(false);
                return;
            }

            _proc.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (e.Data != null) Dispatch(e.Data);
            };
            _proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (e.Data != null) Dispatch(e.Data);
            };
            _proc.EnableRaisingEvents = true;
            _proc.Exited += delegate
            {
                int code = 0;
                try { code = _proc.ExitCode; } catch { }
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    _exitCode = code;
                    _busyFlag = false;
                    StopGlow();
                    StopProgress();
                    FinishStatus();
                    _proc = null;
                }));
            };
            _proc.BeginOutputReadLine();
            _proc.BeginErrorReadLine();
        }

        private void Dispatch(string line)
        {
            Dispatcher.BeginInvoke(new Action(delegate { Append(line); }));
        }

        private void Append(string line)
        {
            _log.AppendText(line + "\r\n");
            _log.CaretIndex = _log.Text.Length;
            _log.ScrollToEnd();
            Note(line);
        }

        private void ClearFoundGames()
        {
            if (_foundWrap != null) _foundWrap.Children.Clear();
            if (_foundTitle != null) _foundTitle.Text = Lang.T("Buscando juegos...", "Looking for games...");
            if (_foundHost != null && _page == "Juegos") _foundHost.Visibility = Visibility.Visible;
        }

        private bool TakeGameLine(string human)
        {
            if (string.IsNullOrEmpty(human) || !human.StartsWith("JUEGO|")) return false;
            string[] parts = human.Split('|');
            if (parts.Length < 3 || _foundWrap == null) return true;
            Border chip = new Border();
            chip.Background = Theme.Card2;
            chip.BorderBrush = Theme.LineStrong;
            chip.BorderThickness = new Thickness(1);
            chip.CornerRadius = new CornerRadius(8);
            chip.Padding = new Thickness(10, 6, 10, 6);
            chip.Margin = new Thickness(0, 0, 8, 8);
            StackPanel text = new StackPanel();
            chip.Child = text;
            TextBlock name = new TextBlock();
            name.Text = parts[2];
            name.Foreground = Theme.Text;
            name.FontSize = 13;
            name.FontWeight = FontWeights.SemiBold;
            text.Children.Add(name);
            TextBlock launcher = new TextBlock();
            launcher.Text = parts[1];
            launcher.Foreground = Theme.Faint;
            launcher.FontSize = 11;
            text.Children.Add(launcher);
            string tweak = TweakForGame(parts[2]);
            if (tweak != null)
            {
                chip.Cursor = Cursors.Hand;
                chip.Tag = tweak + "|" + parts[2];
                TextBlock go = new TextBlock();
                go.Text = Lang.T("Ajustar", "Tweak");
                go.Foreground = Theme.Green;
                go.FontSize = 11;
                go.Margin = new Thickness(0, 2, 0, 0);
                text.Children.Add(go);
                chip.MouseLeftButtonUp += delegate
                {
                    string tag = chip.Tag as string;
                    if (string.IsNullOrEmpty(tag)) return;
                    int cut = tag.IndexOf('|');
                    if (cut < 1) return;
                    Act tweakAct = new Act();
                    tweakAct.Page = "Juegos";
                    tweakAct.Id = "tweak:" + tag.Substring(0, cut);
                    tweakAct.Title = Lang.T("Ajuste de ", "Tweak for ") + tag.Substring(cut + 1);
                    tweakAct.Detail = Lang.T("El tweak de ese juego.", "That game's tweak.");
                    tweakAct.Confirm = true;
                    Run(tweakAct, new Border());
                };
            }
            _foundWrap.Children.Add(chip);
            if (_foundTitle != null)
                _foundTitle.Text = Lang.T("Juegos encontrados: ", "Games found: ") + _foundWrap.Children.Count.ToString();
            if (_foundHost != null && _page == "Juegos") _foundHost.Visibility = Visibility.Visible;
            return true;
        }

        private static string TweakForGame(string name)
        {
            if (string.IsNullOrEmpty(name)) return null;
            string n = name.ToLowerInvariant();
            if (n.IndexOf("counter-strike 2") >= 0 || n == "cs2") return "Apply-CS2Tweaks";
            if (n.IndexOf("valorant") >= 0) return "Apply-ValorantTweaks";
            if (n.IndexOf("rainbow six") >= 0) return "Apply-R6Tweaks";
            if (n.IndexOf("apex legends") >= 0 || n == "apex") return "Apply-ApexTweaks";
            if (n.IndexOf("fortnite") >= 0) return "Apply-FortniteTweaks";
            if (n.IndexOf("warzone") >= 0) return "Apply-WarzoneTweaks";
            if (n.IndexOf("battlefield") >= 0) return "Apply-BattlefieldTweaks";
            if (n.IndexOf("delta force") >= 0) return "Apply-DeltaForceTweaks";
            if (n.IndexOf("the finals") >= 0) return "Apply-TheFinalsTweaks";
            if (n.IndexOf("marvel rivals") >= 0) return "Apply-MarvelRivalsTweaks";
            if (n.IndexOf("league of legends") >= 0) return "Apply-LolTweaks";
            if (n.IndexOf("dota 2") >= 0 || n.IndexOf("dota2") >= 0) return "Apply-Dota2Tweaks";
            if (n == "rust" || n.StartsWith("rust ")) return "Apply-RustTweaks";
            if (n.IndexOf("dayz") >= 0) return "Apply-DayZTweaks";
            if (n == "ark" || n.StartsWith("ark ") || n.IndexOf("ark:") >= 0) return "Apply-ArkTweaks";
            if (n.IndexOf("grand theft auto") >= 0 || n.IndexOf("gta v") >= 0 || n.IndexOf("gta5") >= 0) return "Apply-GTAVTweaks";
            if (n.IndexOf("red dead") >= 0) return "Apply-RDR2Tweaks";
            if (n.IndexOf("cyberpunk") >= 0) return "Apply-CyberpunkTweaks";
            if (n.IndexOf("elden ring") >= 0) return "Apply-EldenRingTweaks";
            if (n.IndexOf("minecraft") >= 0) return "Apply-MinecraftTweaks";
            if (n.IndexOf("tarkov") >= 0) return "Apply-TarkovTweaks";
            if (n.IndexOf("pubg") >= 0 || n.IndexOf("playerunknown") >= 0) return "Apply-PUBGTweaks";
            return null;
        }

        private void ClearStartup()
        {
            if (_startupWrap != null) _startupWrap.Children.Clear();
            if (_startupTitle != null) _startupTitle.Text = Lang.T("Buscando programas de inicio...", "Looking for startup programs...");
            if (_startupHost != null && _page == "Reparar") _startupHost.Visibility = Visibility.Visible;
        }

        private bool TakeStartupLine(string human)
        {
            if (string.IsNullOrEmpty(human) || !human.StartsWith("INICIO|")) return false;
            string[] parts = human.Split('|');
            if (parts.Length < 3 || _startupWrap == null) return true;
            string hive = parts[1];
            string entry = parts[2];
            Border chip = new Border();
            chip.Background = Theme.Card2;
            chip.BorderBrush = Theme.LineStrong;
            chip.BorderThickness = new Thickness(1);
            chip.CornerRadius = new CornerRadius(8);
            chip.Padding = new Thickness(10, 6, 10, 6);
            chip.Margin = new Thickness(0, 0, 8, 8);
            chip.Cursor = Cursors.Hand;
            chip.Tag = hive + "|" + entry;
            StackPanel text = new StackPanel();
            chip.Child = text;
            TextBlock name = new TextBlock();
            name.Text = entry;
            name.Foreground = Theme.Text;
            name.FontSize = 13;
            name.FontWeight = FontWeights.SemiBold;
            text.Children.Add(name);
            TextBlock where = new TextBlock();
            where.Text = hive;
            where.Foreground = Theme.Faint;
            where.FontSize = 11;
            text.Children.Add(where);
            TextBlock go = new TextBlock();
            go.Text = Lang.T("Quitar", "Remove");
            go.Foreground = Theme.Yellow;
            go.FontSize = 11;
            go.Margin = new Thickness(0, 2, 0, 0);
            text.Children.Add(go);
            chip.MouseLeftButtonUp += delegate
            {
                string tag = chip.Tag as string;
                if (string.IsNullOrEmpty(tag)) return;
                int cut = tag.IndexOf('|');
                if (cut < 1) return;
                Act off = new Act();
                off.Page = "Reparar";
                off.Id = "startup-off:" + tag;
                off.Title = Lang.T("Quitar del inicio: ", "Remove from startup: ") + tag.Substring(cut + 1);
                off.Detail = Lang.T("Lo saca del arranque de Windows.", "Removes it from Windows startup.");
                off.Confirm = true;
                Run(off, new Border());
            };
            _startupWrap.Children.Add(chip);
            if (_startupTitle != null)
                _startupTitle.Text = Lang.T("Pulsa Quitar en el que no quieras. ", "Click Remove on the one you don't want. ") + _startupWrap.Children.Count.ToString();
            if (_startupHost != null && _page == "Reparar") _startupHost.Visibility = Visibility.Visible;
            return true;
        }

        private void ShowDriverLink(string url)
        {
            if (string.IsNullOrEmpty(url) || _driverLink == null) return;
            if (!url.StartsWith("https://")) return;
            _driverUrl = url;
            _driverLink.Visibility = Visibility.Visible;
        }

        private void OpenDriverPage()
        {
            if (string.IsNullOrEmpty(_driverUrl) || !_driverUrl.StartsWith("https://")) return;
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = _driverUrl;
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
        }

        private static string PhraseCompare(string raw)
        {
            string[] p = raw.Split('|');
            if (p.Length < 5) return raw;
            string name = p[1];
            if (name == "CPU") name = Lang.T("el procesador", "the processor");
            else if (name == "RAM") name = Lang.T("la memoria", "memory");
            else if (name == "Disk") name = Lang.T("el disco", "the disk");
            else if (name == "Network") name = Lang.T("la red", "the network");
            else if (name == "Full") name = Lang.T("la puntuación", "the score");
            string verb = Lang.T("se quedó igual", "stayed the same");
            if (p[2] == "up") verb = Lang.T("subió", "went up");
            else if (p[2] == "down") verb = Lang.T("bajó", "went down");
            return Lang.T("Comparado: ", "Compared: ") + name + " " + verb + Lang.T(". Antes ", ". Before ") + p[3] + Lang.T(", ahora ", ", now ") + p[4] + ".";
        }

        private string DataRoot()
        {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FamiliaCuba", "GameFixer");
        }

        private void Remember(bool ok)
        {
            if (string.IsNullOrEmpty(_actTitle)) return;
            try
            {
                string dir = DataRoot();
                Directory.CreateDirectory(dir);
                string path = Path.Combine(dir, "actions.log");
                string mode = _live ? "real" : "prueba";
                string state = ok ? "ok" : "fallo";
                string title = _actTitle.Replace("\t", " ").Replace("\r", " ").Replace("\n", " ");
                string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm") + "\t" + title + "\t" + mode + "\t" + state;
                string[] prev = new string[0];
                if (File.Exists(path)) prev = File.ReadAllLines(path);
                List<string> keep = new List<string>();
                int start = prev.Length > 39 ? prev.Length - 39 : 0;
                for (int i = start; i < prev.Length; i++) keep.Add(prev[i]);
                keep.Add(line);
                File.WriteAllLines(path, keep.ToArray());
            }
            catch { }
        }

        private void PaintHistory()
        {
            if (_historyHost == null || _historyList == null) return;
            _historyList.Children.Clear();
            string path = Path.Combine(DataRoot(), "actions.log");
            if (!File.Exists(path))
            {
                _historyHost.Visibility = Visibility.Collapsed;
                return;
            }
            string[] lines = File.ReadAllLines(path);
            int shown = 0;
            for (int i = lines.Length - 1; i >= 0 && shown < 8; i--)
            {
                string[] bits = lines[i].Split('\t');
                if (bits.Length < 4) continue;
                string mode = bits[2] == "real" ? Lang.T("real", "live") : Lang.T("prueba", "test");
                string state = bits[3] == "ok" ? Lang.T("salió bien", "done") : Lang.T("no terminó", "did not finish");
                TextBlock row = new TextBlock();
                row.Text = bits[0] + "   " + bits[1] + "   ·   " + mode + "   ·   " + state;
                row.Foreground = bits[3] == "ok" ? Theme.Muted : Theme.Yellow;
                row.FontSize = 13;
                row.TextWrapping = TextWrapping.Wrap;
                row.Margin = new Thickness(0, 2, 0, 2);
                _historyList.Children.Add(row);
                shown++;
            }
            _historyHost.Visibility = shown > 0 && _page == "Inicio" ? Visibility.Visible : Visibility.Collapsed;
        }

        private void PaintBench()
        {
            if (_benchHost == null || _benchList == null) return;
            _benchList.Children.Clear();
            string path = Path.Combine(DataRoot(), "benchmarks", "last-compare.txt");
            if (!File.Exists(path))
            {
                TextBlock empty = new TextBlock();
                empty.Text = Lang.T("Sale a partir de la segunda medición de cada prueba.", "It appears from the second run of each test.");
                empty.Foreground = Theme.Faint;
                empty.FontSize = 13;
                empty.TextWrapping = TextWrapping.Wrap;
                _benchList.Children.Add(empty);
                _benchHost.Visibility = _page == "Medir" ? Visibility.Visible : Visibility.Collapsed;
                return;
            }
            string[] lines = File.ReadAllLines(path);
            int shown = 0;
            for (int i = 0; i < lines.Length; i++)
            {
                string[] bits = lines[i].Split('\t');
                if (bits.Length < 4) continue;
                string phrase = PhraseCompare("CMP|" + bits[0] + "|" + bits[3] + "|" + bits[1] + "|" + bits[2]);
                TextBlock row = new TextBlock();
                row.Text = phrase;
                row.Foreground = bits[3] == "down" ? Theme.Yellow : Theme.Text;
                row.FontSize = 13;
                row.TextWrapping = TextWrapping.Wrap;
                row.Margin = new Thickness(0, 2, 0, 2);
                _benchList.Children.Add(row);
                shown++;
            }
            _benchHost.Visibility = _page == "Medir" ? Visibility.Visible : Visibility.Collapsed;
            if (shown == 0) _benchHost.Visibility = Visibility.Collapsed;
        }

        private void Note(string line)
        {
            string trimmed = line == null ? "" : line.Trim();
            if (trimmed.StartsWith("DRIVERURL|"))
            {
                ShowDriverLink(trimmed.Substring("DRIVERURL|".Length).Trim());
                return;
            }
            if (trimmed.StartsWith("CMP|"))
            {
                _resultLead = PhraseCompare(trimmed);
                line = _resultLead;
            }
            string code = PullSupportCode(line);
            if (code != null)
            {
                ShowSupportCode(code);
                return;
            }
            WatchStep(line);
            string human = Human(line);
            if (human == null) return;
            int kind = Classify(line);
            string low = line.ToLowerInvariant();
            Brush color = Theme.Text;
            if (kind == 2)
            {
                _sawProblem = true;
                color = Theme.Red;
            }
            else if (kind == 1)
            {
                _sawFinding = true;
                color = Theme.Yellow;
            }
            else if (low.IndexOf("[!]") >= 0 || low.IndexOf("timeout") >= 0)
            {
                color = Theme.Yellow;
            }
            else if (IsSuccessLine(human))
            {
                color = Theme.Green;
                if (IsResultLine(human)) _sawResult = true;
            }
            if (human.StartsWith("Juegos:") || human.StartsWith("No se detectaron juegos") ||
                human.StartsWith("No se encontro ninguna tarjeta"))
            {
                _resultLead = human;
                if (human.StartsWith("No se detectaron juegos") && _foundTitle != null && (_foundWrap == null || _foundWrap.Children.Count == 0))
                    _foundTitle.Text = human;
            }
            else if (human.StartsWith("GPU:") && (_resultLead == null || !_resultLead.StartsWith("GPU:")))
                _resultLead = human;
            if (TakeGameLine(human)) return;
            if (TakeStartupLine(human)) return;
            TextBlock step = new TextBlock();
            step.Text = "•  " + human;
            step.Foreground = color;
            step.TextWrapping = TextWrapping.Wrap;
            step.Margin = new Thickness(0, 2, 0, 2);
            bool list = _actId == "gpuinfo" || _actId == "gpudriver";
            if (list) _steps.Children.Add(step);
            else _steps.Children.Insert(0, step);
            int keep = list ? 6 : 2;
            while (_steps.Children.Count > keep)
                _steps.Children.RemoveAt(list ? 0 : _steps.Children.Count - 1);
            if (list && _stepsScroll != null) _stepsScroll.ScrollToEnd();
        }

        private static int Classify(string raw)
        {
            if (string.IsNullOrEmpty(raw)) return 0;
            string low = raw.ToLowerInvariant();
            if (low.IndexOf("[x]") >= 0 || low.IndexOf("fullyqualifiederrorid") >= 0 ||
                low.IndexOf("parentcontainserrorrecordexception") >= 0 ||
                low.IndexOf("accion desconocida") >= 0 || low.IndexOf("ajuste no permitido") >= 0)
                return 2;
            if (low.IndexOf("[error]") >= 0 || low.IndexOf("[warning]") >= 0 ||
                low.IndexOf("[advertencia]") >= 0 || low.IndexOf("[critical]") >= 0 ||
                low.IndexOf("[critico]") >= 0 || low.IndexOf("[crítico]") >= 0)
                return 1;
            return 0;
        }

        private static bool IsSuccessLine(string human)
        {
            string low = human.ToLowerInvariant();
            return low.IndexOf("completado") >= 0 || low.IndexOf("completada") >= 0 ||
                low.IndexOf("completed") >= 0 ||
                low.IndexOf("hecho.") >= 0 || low.IndexOf("done.") >= 0 ||
                low.IndexOf("sin error") >= 0 || low.IndexOf("no errors") >= 0 ||
                low.IndexOf("sin evento") >= 0 || low.IndexOf("en linea") >= 0 ||
                low.IndexOf("liberad") >= 0 || IsResultLine(human);
        }

        private static bool IsResultLine(string human)
        {
            return human.StartsWith("Procesador:") || human.StartsWith("Processor:") ||
                human.StartsWith("Memoria:") || human.StartsWith("Memory:") ||
                human.StartsWith("Disco") || human.StartsWith("Disk") ||
                human.StartsWith("Red:") || human.StartsWith("Network:") ||
                human.StartsWith("Puntuación:") || human.StartsWith("Score:");
        }

        private static string Human(string line)
        {
            if (string.IsNullOrEmpty(line)) return null;
            string t = line.Trim();
            if (t.Length == 0) return null;
            if (t.StartsWith("===")) return null;
            if (t.StartsWith(">")) return null;
            if (t == "Terminado.") return null;
            if (t.IndexOf("CLIXML", StringComparison.OrdinalIgnoreCase) >= 0) return null;
            bool onlyEq = true;
            for (int i = 0; i < t.Length; i++)
            {
                if (t[i] != '=') { onlyEq = false; break; }
            }
            if (onlyEq) return null;
            int logAt = t.IndexOf(". Log:", StringComparison.OrdinalIgnoreCase);
            if (logAt > 0) t = t.Substring(0, logAt + 1).Trim();
            if (IsHiddenNote(t)) return null;
            string bench = BenchPhrase(t);
            if (bench != null) return bench;
            t = AsWindowsNote(t, "[Error]");
            t = AsWindowsNote(t, "[Warning]");
            t = AsWindowsNote(t, "[Advertencia]");
            t = AsWindowsNote(t, "[Critical]");
            t = AsWindowsNote(t, "[Critico]");
            t = AsWindowsNote(t, "[Crítico]");
            t = t.Replace("Diagnostico completado", Lang.T("Diagnóstico completado", "Diagnostic completed"));
            t = t.Replace("[PRUEBA]", Lang.T("Simulación.", "Simulation."));
            t = t.Replace("[!]", "");
            t = t.Replace("[OK]", Lang.T("Hecho.", "Done."));
            if (t.Length > 160) t = t.Substring(0, 157) + "...";
            return t;
        }

        private static bool IsHiddenNote(string t)
        {
            string low = t.ToLowerInvariant();
            if (low.IndexOf("guardado en") >= 0) return true;
            if (low.IndexOf("historico") >= 0) return true;
            if (low.IndexOf(":\\") >= 0) return true;
            if (low.IndexOf("\\\\") >= 0) return true;
            if (low.StartsWith("ruta:")) return true;
            if (low.StartsWith("archivo:")) return true;
            return false;
        }

        private static string BenchPhrase(string t)
        {
            string low = t.ToLowerInvariant();
            if (low.IndexOf("[cpu] benchmark") >= 0) return Lang.T("Midiendo el procesador...", "Measuring the processor...");
            if (low.IndexOf("[ram] benchmark") >= 0) return Lang.T("Midiendo la memoria...", "Measuring memory...");
            if (low.IndexOf("[disk] benchmarking") >= 0 || low.IndexOf("[disk] benchmark") >= 0) return Lang.T("Midiendo los discos...", "Measuring the disks...");
            if (low.IndexOf("[net] benchmark") >= 0) return Lang.T("Midiendo la red...", "Measuring the network...");
            if (low.IndexOf("ops/s") >= 0 && low.IndexOf("single") >= 0)
            {
                string single = Between(t, "]", "single");
                string multi = Between(t, "/", "multi");
                if (single.Length > 0 && multi.Length > 0)
                    return Lang.T("Procesador: ", "Processor: ") + single + Lang.T(" por núcleo y ", " per core and ") + multi + Lang.T(" con todos, por segundo.", " with all cores, per second.");
            }
            if (low.IndexOf("gaming score") >= 0)
            {
                string score = Between(t, ":", "/");
                if (score.Length > 0) return Lang.T("Puntuación para jugar: ", "Score for gaming: ") + score + Lang.T(" de 100.", " out of 100.");
            }
            if (low.IndexOf("calidad para gaming:") >= 0)
            {
                string q = t.Substring(t.IndexOf(':') + 1).Trim();
                if (q.Length > 0) return Lang.T("Para jugar va ", "For gaming it is ") + q.ToLowerInvariant() + ".";
            }
            if (low.IndexOf("ping") >= 0 && low.IndexOf("mbps") >= 0)
            {
                string ping = Between(low, "ping", "ms");
                string down = Between(low, "down", "mbps");
                string quality = "";
                int bar = t.LastIndexOf('|');
                if (bar >= 0) quality = t.Substring(bar + 1).Trim().ToLowerInvariant();
                if (ping.Length > 0 && down.Length > 0)
                {
                    string phrase = Lang.T("Red: responde en ", "Network: responds in ") + ping + Lang.T(" ms y baja a ", " ms and downloads at ") + down + " Mb/s.";
                    if (quality.Length > 0) phrase = phrase + Lang.T(" Va ", " It is ") + quality + ".";
                    return phrase;
                }
            }
            if ((low.IndexOf("ssd") >= 0 || low.IndexOf("hdd") >= 0 || low.IndexOf("discos:") >= 0) &&
                low.IndexOf("read") >= 0 && low.IndexOf("write") >= 0)
            {
                string read = Between(low, "read", "mb/s");
                string write = Between(low, "write", "mb/s");
                if (read.Length > 0 && write.Length > 0)
                {
                    if (low.IndexOf("discos:") >= 0)
                        return Lang.T("Discos: leen de media a ", "Disks: average read ") + read.Trim() + Lang.T(" MB/s y escriben a ", " MB/s and write ") + write.Trim() + " MB/s.";
                    string kind = low.IndexOf("ssd") >= 0 ? "SSD" : "HDD";
                    string letter = Between(t, "[", " ");
                    if (letter.Length == 0) letter = Lang.T("del sistema", "system");
                    return Lang.T("Disco ", "Disk ") + letter + " (" + kind + "): " + Lang.T("lee a ", "reads at ") + read.Trim() + Lang.T(" MB/s y escribe a ", " MB/s and writes at ") + write.Trim() + " MB/s.";
                }
            }
            if (low.IndexOf("write") >= 0 && low.IndexOf("read") >= 0 && low.IndexOf("mb/s") >= 0)
            {
                string write = Between(low, "write", "mb/s");
                string read = Between(low, "read", "mb/s");
                if (write.Length > 0 && read.Length > 0)
                    return Lang.T("Memoria: escribe a ", "Memory: writes at ") + write.Trim() + Lang.T(" MB/s y lee a ", " MB/s and reads at ") + read.Trim() + " MB/s.";
            }
            return null;
        }

        private static string Between(string text, string start, string end)
        {
            int a = text.IndexOf(start, StringComparison.OrdinalIgnoreCase);
            if (a < 0) return "";
            a += start.Length;
            int b = text.IndexOf(end, a, StringComparison.OrdinalIgnoreCase);
            if (b < a) return "";
            return text.Substring(a, b - a).Trim();
        }

        private static string AsWindowsNote(string t, string tag)
        {
            if (!t.StartsWith(tag, StringComparison.OrdinalIgnoreCase)) return t;
            return Lang.T("Aviso de Windows: ", "Windows notice: ") + t.Substring(tag.Length).Trim();
        }

        private static string PullSupportCode(string line)
        {
            if (string.IsNullOrEmpty(line)) return null;
            int mark = line.IndexOf("GF-", StringComparison.Ordinal);
            if (mark < 0) return null;
            if (line.IndexOf("soporte", StringComparison.OrdinalIgnoreCase) < 0 &&
                line.IndexOf("support", StringComparison.OrdinalIgnoreCase) < 0)
                return null;
            string rest = line.Substring(mark).Trim();
            int space = rest.IndexOf(' ');
            if (space > 0) rest = rest.Substring(0, space);
            if (rest.Length < 6) return null;
            return rest;
        }

        private void ShowSupportCode(string code)
        {
            _supportCode = code;
            if (_codeText != null) _codeText.Text = code;
            if (_codeCard != null) _codeCard.Visibility = Visibility.Visible;
            if (_copyLabel != null) _copyLabel.Text = Lang.T("Copiar", "Copy");
            if (_pageCopyLabel != null) _pageCopyLabel.Text = Lang.T("Copiar", "Copy");
            if (_pageCodeText != null) _pageCodeText.Text = code;
            if (_pageCodeCard != null) _pageCodeCard.Visibility = Visibility.Visible;
        }

        private void CopySupportCode()
        {
            if (string.IsNullOrEmpty(_supportCode)) return;
            try { Clipboard.SetText(_supportCode); }
            catch { return; }
            if (_copyLabel != null) _copyLabel.Text = Lang.T("Copiado", "Copied");
            if (_pageCopyLabel != null) _pageCopyLabel.Text = Lang.T("Copiado", "Copied");
            DispatcherTimer back = new DispatcherTimer();
            back.Interval = TimeSpan.FromMilliseconds(1400);
            back.Tick += delegate
            {
                back.Stop();
                if (_copyLabel != null) _copyLabel.Text = Lang.T("Copiar", "Copy");
                if (_pageCopyLabel != null) _pageCopyLabel.Text = Lang.T("Copiar", "Copy");
            };
            back.Start();
        }

        private void WatchStep(string raw)
        {
            if (string.IsNullOrEmpty(raw)) return;
            int a = raw.IndexOf('[');
            int slash = raw.IndexOf('/');
            int b = raw.IndexOf(']');
            if (a < 0 || slash < a || b < slash) return;
            if (slash - a > 4 || b - slash > 4) return;
            int n;
            int m;
            if (!int.TryParse(raw.Substring(a + 1, slash - a - 1).Trim(), out n)) return;
            if (!int.TryParse(raw.Substring(slash + 1, b - slash - 1).Trim(), out m)) return;
            if (m < 2 || m > 30 || n < 1 || n > m) return;
            SetPercent(n * 100.0 / m);
        }

        private void StartProgress()
        {
            if (_barFill != null) _barFill.Background = Theme.Cobalt;
            if (_pctLabel != null)
            {
                _pctLabel.Foreground = Theme.Text;
                _pctLabel.Text = "…";
            }
            if (_barScale == null) return;
            DoubleAnimation pulse = new DoubleAnimation(0.08, 0.46, TimeSpan.FromSeconds(0.85));
            pulse.AutoReverse = true;
            pulse.RepeatBehavior = RepeatBehavior.Forever;
            _barScale.BeginAnimation(ScaleTransform.ScaleXProperty, pulse);
        }

        private void StopProgress()
        {
            if (_barScale != null) _barScale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
        }

        private void SetPercent(double pct)
        {
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
            if (_barScale != null)
            {
                _barScale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
                DoubleAnimation go = new DoubleAnimation(pct / 100.0, TimeSpan.FromMilliseconds(280));
                _barScale.BeginAnimation(ScaleTransform.ScaleXProperty, go);
            }
            if (_pctLabel != null)
            {
                _pctLabel.Text = ((int)Math.Round(pct)).ToString() + "%";
                _pctLabel.Foreground = Theme.Text;
            }
        }

        private void FinishStatus()
        {
            bool ok = !_sawProblem && _exitCode == 0;
            Remember(ok);
            if (ok && _live && _actId != null && _actId.StartsWith("startup-off:") && _startupWrap != null)
            {
                string tag = _actId.Substring("startup-off:".Length);
                for (int i = _startupWrap.Children.Count - 1; i >= 0; i--)
                {
                    Border chip = _startupWrap.Children[i] as Border;
                    if (chip != null && (chip.Tag as string) == tag) _startupWrap.Children.RemoveAt(i);
                }
            }
            if (_page == "Inicio") PaintHistory();
            if (_page == "Medir") PaintBench();
            if (!ok)
            {
                _statusTitle.Text = Lang.T("No se pudo completar", "Could not finish");
                _statusTitle.Foreground = Theme.Red;
                if (_barFill != null) _barFill.Background = Theme.Red;
                if (_pctLabel != null) _pctLabel.Foreground = Theme.Red;
                _statusBody.Text = Lang.T("Esta acción no terminó. Pulsa «Ver detalle técnico» para ver el motivo.", "This action did not finish. Open technical detail to see why.");
                return;
            }
            SetPercent(100);
            if (_barFill != null) _barFill.Background = Theme.Green;
            if (_pctLabel != null) _pctLabel.Foreground = Theme.Green;
            _statusTitle.Text = Lang.T("Salió bien", "Done");
            _statusTitle.Foreground = Theme.Green;
            if (!string.IsNullOrEmpty(_resultLead))
                _statusBody.Text = _resultLead;
            else if (_sawResult)
                _statusBody.Text = Lang.T("La medición terminó. El resultado está aquí abajo.", "The measurement finished. The result is just below.");
            else if (!_lastConfirm)
                _statusBody.Text = Lang.T("Se completó. Solo fue una revisión: tu PC no cambió.", "Finished. It was only a check: your PC did not change.");
            else if (!_live)
                _statusBody.Text = Lang.T("La prueba salió bien. No se cambió nada. Para aplicarlo, pulsa Real y vuelve a ejecutar.", "The test went fine. Nothing was changed. To apply it, switch to Live and run it again.");
            else
                _statusBody.Text = Lang.T("Se aplicó bien en tu PC.", "It was applied on your PC.");
            if (_sawFinding)
                _statusBody.Text = _statusBody.Text + Lang.T(" La nota de abajo es del equipo, no un fallo de esta acción.", " The note below comes from the PC, not a failure of this action.");
        }

        private void StopProc()
        {
            try
            {
                if (_proc != null && !_proc.HasExited) _proc.Kill();
            }
            catch { }
        }

        private void WarmPayload()
        {
            try { ResolveRoot(); }
            catch { }
        }

        private string ResolveRoot()
        {
            lock (_payloadLock)
            {
                if (_payloadRoot != null) return _payloadRoot;
                string root = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "FamiliaCuba", "GameFixer");
                Directory.CreateDirectory(root);
                string stamp = Path.Combine(root, "payload.ver");
                string zip = Path.Combine(root, "payload.zip");
                string ps1 = Path.Combine(root, "GameFixer.ps1");
                bool fresh = !File.Exists(stamp) || File.ReadAllText(stamp).Trim() != Version;
                bool hasAction = false;
                if (File.Exists(ps1))
                {
                    string head = File.ReadAllText(ps1);
                    hasAction = head.IndexOf("[string]$Action", StringComparison.Ordinal) >= 0;
                }
                bool hasStartup = false;
                string bridge = Path.Combine(root, "modules", "GuiBridge.psm1");
                if (File.Exists(bridge))
                    hasStartup = File.ReadAllText(bridge).IndexOf("function Show-GuiStartup", StringComparison.Ordinal) >= 0;
                if (fresh || !hasAction || !hasStartup)
                {
                    Stream src = Assembly.GetExecutingAssembly().GetManifestResourceStream("GF.payload");
                    if (src == null) throw new InvalidOperationException("Falta el paquete interno.");
                    FileStream dst = File.Create(zip);
                    byte[] buf = new byte[65536];
                    int n;
                    while ((n = src.Read(buf, 0, buf.Length)) > 0) dst.Write(buf, 0, n);
                    dst.Close();
                    src.Close();
                    Expand(zip, root);
                    File.WriteAllText(stamp, Version);
                }
                _payloadRoot = root;
                return root;
            }
        }

        private static void Expand(string zipPath, string root)
        {
            string cmd = "Expand-Archive -LiteralPath '" + zipPath.Replace("'", "''") +
                "' -DestinationPath '" + root.Replace("'", "''") + "' -Force";
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"" + cmd + "\"";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            Process p = Process.Start(psi);
            p.WaitForExit();
            if (p.ExitCode != 0) throw new InvalidOperationException("No se pudo descomprimir.");
        }

        private static Act[] BuildActs()
        {
            return new Act[] {
                A("Inicio", "diagnostico", Lang.T("Diagnóstico completo", "Full diagnostic"), Lang.T("Sistema, CPU, GPU, discos y eventos. No cambia nada.", "System, CPU, GPU, disks and events. Changes nothing."), false),
                A("Inicio", "salud", Lang.T("Salud de Windows", "Windows health"), Lang.T("Servicios, almacenamiento y señales de problema.", "Services, storage and problem signs."), false),
                A("Inicio", "autodiag", Lang.T("Diagnóstico rápido", "Quick diagnostic"), Lang.T("Revisa hardware, drivers y ajustes de juego.", "Checks hardware, drivers and game settings."), false),
                A("Inicio", "autofix", "Auto-Fix", Lang.T("Restauración, benchmark, limpieza, tweaks y reporte. Pide confirmación.", "Restore point, benchmark, cleanup, tweaks and report. Asks first."), true),
                A("Inicio", "optimizar", Lang.T("Optimización gamer", "Gamer optimization"), Lang.T("Plan de energía, Game Mode y red. Respeta el modo prueba.", "Power plan, Game Mode and network. Test mode is respected."), true),

                A("Reparar", "startup", Lang.T("Programas de inicio", "Startup programs"), Lang.T("Lista lo que arranca con Windows. Pulsa uno para quitarlo. Respeta el modo prueba.", "Lists what starts with Windows. Click one to remove it. Test mode is respected."), false),
                A("Reparar", "limpieza", Lang.T("Limpiar temporales", "Clean temporary files"), Lang.T("Todas las categorías de limpieza de una vez.", "Every cleanup category at once."), true),
                A("Reparar", "papelera", Lang.T("Vaciar papelera", "Empty recycle bin"), Lang.T("Vacía la papelera de reciclaje.", "Empties the recycle bin."), true),
                A("Reparar", "winsxs", Lang.T("Limpiar WinSxS", "Clean WinSxS"), Lang.T("Componentes antiguos de Windows.", "Old Windows components."), true),
                A("Reparar", "sfc", "SFC", Lang.T("Comprueba los archivos de Windows.", "Checks the Windows files."), true),
                A("Reparar", "dism", "DISM", Lang.T("Repara la imagen de Windows.", "Repairs the Windows image."), true),
                A("Reparar", "reparar", Lang.T("SFC y DISM", "SFC and DISM"), Lang.T("Las dos reparaciones seguidas.", "Both repairs, one after the other."), true),
                A("Reparar", "chkdsk", "CHKDSK", Lang.T("Revisa C: en solo lectura. No agenda un reinicio.", "Checks C: read-only. It does not schedule a restart."), true),
                A("Reparar", "stutter", Lang.T("Tirones", "Stutter"), Lang.T("Ajustes habituales contra el stuttering.", "Usual settings against stuttering."), true),
                A("Reparar", "audio", Lang.T("Audio", "Audio"), Lang.T("Reinicia la pila de audio.", "Restarts the audio stack."), true),
                A("Reparar", "inputlag", "Input lag", Lang.T("Ajustes de latencia de entrada.", "Input latency settings."), true),
                A("Reparar", "hags", Lang.T("Activar HAGS", "Enable HAGS"), "Hardware-accelerated GPU scheduling.", true),
                A("Reparar", "mouse", Lang.T("Quitar aceleración del ratón", "Turn off mouse acceleration"), Lang.T("Desactiva la aceleración del puntero.", "Turns off pointer acceleration."), true),
                A("Reparar", "restorepoint", Lang.T("Punto de restauración", "Restore point"), Lang.T("Crea un punto antes de otros cambios.", "Creates a point before other changes."), true),
                A("Reparar", "backups", Lang.T("Ver copias", "View backups"), Lang.T("Lista los backups de registro guardados.", "Lists the saved registry backups."), false),
                A("Reparar", "rollback", Lang.T("Restaurar último backup", "Restore last backup"), Lang.T("Vuelve al último backup de registro.", "Goes back to the last registry backup."), true),

                A("Juegos", "juegos", Lang.T("Detectar juegos", "Detect games"), Lang.T("Steam, Epic, Riot, Xbox, EA, Ubisoft y GOG.", "Steam, Epic, Riot, Xbox, EA, Ubisoft and GOG."), false),
                A("Juegos", "gpuinfo", Lang.T("Información de la GPU", "GPU information"), Lang.T("Nombre, driver y memoria.", "Name, driver and memory."), false),
                A("Juegos", "gpudriver", Lang.T("Versión del driver", "Driver version"), Lang.T("Comprueba el driver instalado.", "Checks the installed driver."), false),
                A("Juegos", "shaders", Lang.T("Borrar caché de shaders", "Clear shader cache"), Lang.T("Limpia la caché de shaders de la GPU.", "Clears the GPU shader cache."), true),
                A("Juegos", "gpuperf", Lang.T("GPU a máximo rendimiento", "GPU maximum performance"), Lang.T("Plan de energía de la tarjeta.", "The graphics card power plan."), true),
                A("Juegos", "perfil-gamer", Lang.T("Perfil Gamer", "Gamer profile"), Lang.T("El perfil de rendimiento del menú.", "The performance profile from the menu."), true),
                A("Juegos", "perfil-streaming", Lang.T("Perfil Streaming", "Streaming profile"), Lang.T("El perfil de streaming del menú.", "The streaming profile from the menu."), true),
                A("Juegos", "perfil-oficina", Lang.T("Perfil Oficina", "Office profile"), Lang.T("El perfil equilibrado.", "The balanced profile."), true),
                A("Juegos", "perfil-ahorro", Lang.T("Perfil Ahorro", "Power saver profile"), Lang.T("El perfil de bajo consumo.", "The low-power profile."), true),
                A("Juegos", "plugins", Lang.T("Ver plugins", "View plugins"), Lang.T("Lista los plugins de la carpeta.", "Lists the plugins in the folder."), false),
                T("CS2", "Apply-CS2Tweaks"),
                T("VALORANT", "Apply-ValorantTweaks"),
                T("Rainbow Six", "Apply-R6Tweaks"),
                T("Apex", "Apply-ApexTweaks"),
                T("Fortnite", "Apply-FortniteTweaks"),
                T("Warzone", "Apply-WarzoneTweaks"),
                T("Battlefield", "Apply-BattlefieldTweaks"),
                T("Delta Force", "Apply-DeltaForceTweaks"),
                T("The Finals", "Apply-TheFinalsTweaks"),
                T("Marvel Rivals", "Apply-MarvelRivalsTweaks"),
                T("League of Legends", "Apply-LolTweaks"),
                T("Dota 2", "Apply-Dota2Tweaks"),
                T("Rust", "Apply-RustTweaks"),
                T("DayZ", "Apply-DayZTweaks"),
                T("ARK", "Apply-ArkTweaks"),
                T("GTA V", "Apply-GTAVTweaks"),
                T("Red Dead 2", "Apply-RDR2Tweaks"),
                T("Cyberpunk 2077", "Apply-CyberpunkTweaks"),
                T("Elden Ring", "Apply-EldenRingTweaks"),
                T("Minecraft", "Apply-MinecraftTweaks"),
                T("Tarkov", "Apply-TarkovTweaks"),
                T("PUBG", "Apply-PUBGTweaks"),

                A("Red", "latencia", Lang.T("Latencia", "Latency"), Lang.T("Ping a los destinos del módulo de red.", "Ping to the network module targets."), false),
                A("Red", "conexiones", Lang.T("Conexiones", "Connections"), Lang.T("Muestra las conexiones activas.", "Shows the active connections."), false),
                A("Red", "dns-cf", "DNS Cloudflare", Lang.T("Pone 1.1.1.1. Respeta el modo prueba.", "Sets 1.1.1.1. Test mode is respected."), true),
                A("Red", "dns-google", "DNS Google", Lang.T("Pone 8.8.8.8. Respeta el modo prueba.", "Sets 8.8.8.8. Test mode is respected."), true),
                A("Red", "dns-reset", Lang.T("Restablecer DNS", "Reset DNS"), Lang.T("Vuelve al DNS automático.", "Goes back to automatic DNS."), true),
                A("Red", "resetred", Lang.T("Reiniciar adaptador", "Restart adapter"), Lang.T("Vacia el DNS y reinicia el adaptador con internet. No corta la pila.", "Flushes DNS and restarts the adapter that has internet. It does not reset the stack."), true),

                A("Medir", "bench-cpu", "Benchmark CPU", Lang.T("La prueba de CPU que ya estaba.", "The existing CPU test."), false),
                A("Medir", "bench-ram", "Benchmark RAM", Lang.T("La prueba de memoria.", "The memory test."), false),
                A("Medir", "bench-disk", Lang.T("Benchmark disco", "Disk benchmark"), Lang.T("La prueba de disco.", "The disk test."), false),
                A("Medir", "bench-net", Lang.T("Benchmark red", "Network benchmark"), Lang.T("La prueba de red.", "The network test."), false),
                A("Medir", "bench-full", Lang.T("Benchmark completo", "Full benchmark"), Lang.T("CPU, RAM, disco y red, con comparativa.", "CPU, RAM, disk and network, with a comparison."), false)
            };
        }

        private static Act A(string page, string id, string title, string detail, bool confirm)
        {
            Act a = new Act();
            a.Page = page;
            a.Id = id;
            a.Title = title;
            a.Detail = detail;
            a.Confirm = confirm;
            return a;
        }

        private static Brush CardBrush()
        {
            LinearGradientBrush brush = new LinearGradientBrush();
            brush.StartPoint = new Point(0, 0);
            brush.EndPoint = new Point(1, 1);
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(0x40, 0x44, 0x4A), 0));
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(0x34, 0x38, 0x3E), 1));
            brush.Freeze();
            return brush;
        }

        private static Act T(string name, string func)
        {
            return A("Juegos", "tweak:" + func, Lang.T("Ajuste  ", "Tweak  ") + name, Lang.T("El tweak de ese juego. Respeta el modo prueba.", "That game's tweak. Test mode is respected."), true);
        }
    }
}
