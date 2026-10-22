// Generated from FestiCore-DesignSystem e8a0aec50760526e20492f7d166752c4058dea21
// Source: tokens/color/{atomic,semantic.light,semantic.dark}.json
import UIKit

public enum FestiCoreColor {
  public static var primaryNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.776470588, 1, 0.203921569, 1) : (0.0666666667, 0.0666666667, 0.0745098039, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var primaryOnPrimary: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0666666667, 0.0666666667, 0.0745098039, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var secondaryNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.698039216, 0.545098039, 1, 1) : (0.498039216, 0.22745098, 0.937254902, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var secondaryOnSecondary: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0666666667, 0.0666666667, 0.0745098039, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var labelStrong: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 1) : (0, 0, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var labelNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 1) : (0.0666666667, 0.0666666667, 0.0745098039, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var labelNeutral: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.788235294, 0.788235294, 0.811764706, 1) : (0.360784314, 0.360784314, 0.4, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var labelAssistive: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.662745098, 0.662745098, 0.694117647, 1) : (0.541176471, 0.541176471, 0.576470588, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var labelDisable: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.164705882, 0.164705882, 0.188235294, 1) : (0.788235294, 0.788235294, 0.811764706, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var backgroundNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0666666667, 0.0666666667, 0.0745098039, 1) : (0.952941176, 0.952941176, 0.964705882, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var backgroundAlternative: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 1) : (0.91372549, 0.91372549, 0.933333333, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var backgroundElevated: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.109803922, 0.109803922, 0.125490196, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var backgroundNavigation: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.109803922, 0.109803922, 0.125490196, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var lineNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.164705882, 0.164705882, 0.188235294, 1) : (0.894117647, 0.894117647, 0.909803922, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var lineStrong: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.360784314, 0.360784314, 0.4, 1) : (0.788235294, 0.788235294, 0.811764706, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var fillNormal: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.101960784) : (0.949019608, 0.949019608, 0.956862745, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var fillStrong: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.2) : (0.894117647, 0.894117647, 0.909803922, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var fillSelected: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.360784314, 0.360784314, 0.4, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var statusPositive: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.188235294, 0.819607843, 0.345098039, 1) : (0.203921569, 0.780392157, 0.349019608, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var statusCautionary: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.623529412, 0.0392156863, 1) : (1, 0.584313725, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var statusNegative: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.270588235, 0.22745098, 1) : (1, 0.231372549, 0.188235294, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var statusInfo: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0392156863, 0.517647059, 1, 1) : (0, 0.478431373, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticWhite: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticBlack: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 1) : (0, 0, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticLime: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.776470588, 1, 0.203921569, 1) : (0.776470588, 1, 0.203921569, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticInk: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0666666667, 0.0666666667, 0.0745098039, 1) : (0.0666666667, 0.0666666667, 0.0745098039, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticPurpleTint: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.964705882, 0.949019608, 1, 1) : (0.964705882, 0.949019608, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaBlack80: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.8) : (0, 0, 0, 0.8)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaBlack60: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.6) : (0, 0, 0, 0.6)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaBlack40: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.4) : (0, 0, 0, 0.4)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaBlack20: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.2) : (0, 0, 0, 0.2)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaWhite80: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.8) : (1, 1, 1, 0.8)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaWhite60: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.6) : (1, 1, 1, 0.6)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaWhite40: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.4) : (1, 1, 1, 0.4)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var staticalphaWhite20: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.2) : (1, 1, 1, 0.2)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var inverseBackground: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 1) : (0.0666666667, 0.0666666667, 0.0745098039, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var inverseLabel: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.0666666667, 0.0666666667, 0.0745098039, 1) : (1, 1, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var materialDimmer: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.698039216) : (0, 0, 0, 0.501960784)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var materialGlass: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0, 0, 0, 0.2) : (1, 1, 1, 0.2)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var interactionPressed: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.101960784) : (0.0666666667, 0.0666666667, 0.0745098039, 0.101960784)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var interactionActive: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 1, 1, 0.0509803922) : (0.0666666667, 0.0666666667, 0.0745098039, 0.0509803922)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundLime: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.776470588, 1, 0.203921569, 1) : (0.305882353, 0.450980392, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundPurple: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.498039216, 0.22745098, 0.937254902, 1) : (0.356862745, 0.129411765, 0.768627451, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundRed: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.301960784, 0.239215686, 1) : (0.760784314, 0.121568627, 0.0705882353, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundOrange: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.603921569, 0.180392157, 1) : (0.650980392, 0.31372549, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundGreen: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.184313725, 0.749019608, 0.356862745, 1) : (0.0823529412, 0.478431373, 0.211764706, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundBlue: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.239215686, 0.482352941, 1, 1) : (0.121568627, 0.309803922, 0.8, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundPink: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.435294118, 0.784313725, 1) : (0.721568627, 0.137254902, 0.498039216, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentForegroundYellow: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.850980392, 0.239215686, 1) : (0.478431373, 0.376470588, 0, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundLime: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.776470588, 1, 0.203921569, 0.101960784) : (0.949019608, 0.97254902, 0.882352941, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundPurple: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.498039216, 0.22745098, 0.937254902, 0.101960784) : (0.964705882, 0.949019608, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundRed: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.301960784, 0.239215686, 0.101960784) : (1, 0.945098039, 0.937254902, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundOrange: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.603921569, 0.180392157, 0.101960784) : (1, 0.949019608, 0.898039216, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundGreen: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.184313725, 0.749019608, 0.356862745, 0.101960784) : (0.901960784, 0.984313725, 0.921568627, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundBlue: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.239215686, 0.482352941, 1, 0.101960784) : (0.937254902, 0.960784314, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundPink: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.435294118, 0.784313725, 0.101960784) : (1, 0.937254902, 0.97254902, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentBackgroundYellow: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.850980392, 0.239215686, 0.101960784) : (0.976470588, 0.960784314, 0.874509804, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointLime: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.776470588, 1, 0.203921569, 1) : (0.776470588, 1, 0.203921569, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointPurple: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.498039216, 0.22745098, 0.937254902, 1) : (0.498039216, 0.22745098, 0.937254902, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointRed: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.301960784, 0.239215686, 1) : (1, 0.301960784, 0.239215686, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointOrange: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.603921569, 0.180392157, 1) : (1, 0.603921569, 0.180392157, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointGreen: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.184313725, 0.749019608, 0.356862745, 1) : (0.184313725, 0.749019608, 0.356862745, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointBlue: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (0.239215686, 0.482352941, 1, 1) : (0.239215686, 0.482352941, 1, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointPink: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.435294118, 0.784313725, 1) : (1, 0.435294118, 0.784313725, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

  public static var accentPointYellow: UIColor {
    UIColor { traits in
      let rgba: (CGFloat, CGFloat, CGFloat, CGFloat) = traits.userInterfaceStyle == .dark ? (1, 0.850980392, 0.239215686, 1) : (1, 0.850980392, 0.239215686, 1)
      return UIColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
    }
  }

}
