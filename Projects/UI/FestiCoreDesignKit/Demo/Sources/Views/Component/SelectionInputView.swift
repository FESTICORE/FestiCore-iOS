//
//  SelectionInputView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct SelectionInputView: View {
  @State private var isToggleOn = true
  @State private var nickname = "민지"
  @State private var keyword = ""
  @State private var isConsentChecked = false
  @State private var isChecklistChecked = false
  @State private var isSetSelected = false
  @State private var newItem = ""

  var body: some View {
    DemoPage("03 Selection & Input 검증") {
      DemoSection("Toggle · Check Circle") {
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCToggle(
            isOn: $isToggleOn,
            accessibilityLabel: "알림"
          )
          FCCheckCircle(isChecked: true)
          FCCheckCircle(isChecked: false)
        }
      }
      DemoSection("Text Field (filled · error)") {
        FCTextField(
          text: $nickname,
          placeholder: "닉네임을 입력해 주세요"
        )
          .label("닉네임")
          .maxLength(12)
          .helper("크루원과 깃발에 보이는 이름이에요. 나중에 마이에서 바꿀 수 있어요.")
        FCTextField(
          text: $nickname,
          placeholder: "닉네임을 입력해 주세요"
        )
          .label("닉네임")
          .maxLength(12)
          .error("이미 쓰고 있는 닉네임이에요. 다른 이름을 지어주세요.")
      }
      DemoSection("Search Field · Recent Keyword · Field Label") {
        FCSearchField(text: $keyword)
        FCRecentKeyword(
          "펜타포트",
          onSelect: {},
          onDelete: {}
        )
        FCFieldLabel("성향 태그")
          .counter("0 / 3")
      }
      DemoSection("Consent All · Consent Row") {
        VStack(spacing: 0) {
          FCConsentAll(isChecked: isConsentChecked) { isConsentChecked.toggle() }
          FCConsentRow(
            "서비스 이용약관",
            isChecked: isConsentChecked
          ) { isConsentChecked.toggle() }
            .tag("필수")
            .onDetail {}
          FCConsentRow(
            "마케팅 알림 받기",
            isChecked: isConsentChecked
          ) { isConsentChecked.toggle() }
            .tag("선택")
            .sub("공연 10분 전 · 팔로우한 깃발 · 크루 소식")
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
      }
      DemoSection("Checklist Row · Set Select Row") {
        FCChecklistRow(
          "보조배터리",
          isChecked: isChecklistChecked
        ) { isChecklistChecked.toggle() }
        FCSetSelectRow(
          artist: "coldrain",
          stage: "WONDER STAGE",
          start: "16:40",
          end: "17:30",
          isSelected: isSetSelected
        ) {
          isSetSelected.toggle()
        }
        .overlapText(isSetSelected ? "SPYAIR와 20분 겹쳐요" : nil)
      }
      DemoSection("Checklist Edit Row · Add Item Row") {
        VStack(spacing: 0) {
          FCChecklistEditRow("귀마개")
            .onDelete {}
          FCChecklistEditRow("티켓")
          FCAddItemRow(text: $newItem) { newItem = "" }
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
      }
      DemoSection("Photo Picker (empty · uploading · filled)") {
        FCPhotoPicker(.empty) {}
        FCPhotoPicker(.uploading(image: Image(systemName: "photo"), progress: 0.64)) {}
        FCPhotoPicker(.filled(Image(systemName: "photo"))) {}
      }
    }
  }
}

#Preview {
  NavigationStack {
    SelectionInputView()
  }
}
