$Path = "lib\screens\home_screen.dart"
$Content = Get-Content -Path $Path -Encoding UTF8 -Raw

# 1. Fix _safeExtractString and remove the broken build method
$Target1 = @'
  String? _safeExtractString(dynamic value) {  
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // إذا كانت القيمة خريطة، حاول استخراج ح 
 @override
  Widget build(BuildContext context) {
    return SmartFluidPanel(
      padding: EdgeInsets.all(24.r),
      borderRadius: 32.r,
      useBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SmartSoftIcon(
                icon: LucideIcons.sparkles,    
                color: Color(0xFF00FF88),      
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  "الذكاء الإصطناعي ✨",
'@

$Replacement1 = @'
  String? _safeExtractString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // إذا كانت القيمة خريطة، حاول استخراج النص
      return value['content']?.toString() ?? value['text']?.toString();
    }
    return value.toString();
  }
'@

$Content = $Content.Replace($Target1, $Replacement1)

# 2. Fix the corrupted end of build and stray text
$Target2 = @'
          SmartNeonButton(
            text: "ابدأ المحادثة الآن",      
            onPressed: () => Get.find<NavigationController>().changePage(1),
            gradientColors: const [Color(0xFF00FF88), Color(0xFF00FFEE)],
            shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
            borderRadius: 50.r, // 🔥 Pill Shape
          ),
        ],
      ),
    );
  }
محادثة الآن",
            onPressed: () => Get.find<NavigationController>().changePage(1),
            gradientColors: const [Color(0xFF00FF88), Color(0xFF00FFEE)],
            shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
            borderRadius: 16.r,
          ),
        ],
      ),
    );
  }
'@

$Replacement2 = @'
          SmartNeonButton(
            text: "ابدأ المحادثة الآن",
            onPressed: () => Get.find<NavigationController>().changePage(1),
            gradientColors: const [Color(0xFF00FF88), Color(0xFF00FFEE)],
            shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
            borderRadius: 50.r, // 🔥 Pill Shape
          ),
        ],
      ),
    );
  }
'@

$Content = $Content.Replace($Target2, $Replacement2)

Set-Content -Path $Path -Value $Content -Encoding UTF8
