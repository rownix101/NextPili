/// Thin re-exports / helpers around liquid_glass_widgets for chrome only.
/// Feed cards and lists must stay opaque — do not wrap content in glass.
library;

export 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        AdaptiveLiquidGlassLayer,
        GlassAppBar,
        GlassButton,
        GlassCard,
        GlassContainer,
        GlassDialog,
        GlassDialogAction,
        GlassGroupedSection,
        GlassIconButton,
        GlassInteractionBehavior,
        GlassListTile,
        GlassMenu,
        GlassModalSheet,
        GlassPage,
        GlassQuality,
        GlassScaffold,
        GlassSearchBar,
        GlassSegment,
        GlassSegmentedControl,
        GlassSlider,
        GlassSpecularSharpness,
        GlassTab,
        GlassTabBar,
        GlassTextField,
        GlassToolbar,
        LiquidGlassSettings,
        LiquidGlassWidgets,
        LiquidRoundedSuperellipse;

export 'glass_panel.dart';
export 'mobile_glass_tab_bar.dart';
