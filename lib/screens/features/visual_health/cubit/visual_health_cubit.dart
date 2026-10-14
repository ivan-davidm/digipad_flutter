import 'package:bloc/bloc.dart';
import 'package:digipad_flutter/screens/features/visual_health/cubit/visual_health_state.dart';

class VisualHealthCubit extends Cubit<VisualHealthState> {
  VisualHealthCubit() : super(VisualHealthState());

  static const String _base = 'assets/images/visual_health';

  void initTests() {
    final categoryImages = <VisualHealthCategory, List<String>>{
      VisualHealthCategory.visionTests: [
        '$_base/01-Test de Lectura.webp',
        '$_base/02-Agudeza visual.webp',
        '$_base/vh_clock.png',
      ],
      VisualHealthCategory.ishihara: [
        '$_base/03-Bicromatico.webp',
        '$_base/04-Ishiara1 .webp',
        '$_base/05-Ishiara2.webp',
        '$_base/06-Ishiara3.webp',
        '$_base/07-Ishiara4.webp',
        '$_base/08-Ishiara5.webp',
        '$_base/09-Ishiara6.webp',
        '$_base/10-Ishiara7.webp',
        '$_base/11-Ishiara8.webp',
        '$_base/12-Ishiara9.webp',
        '$_base/13-Ishiara10.webp',
        '$_base/14-Ishiara11.webp',
        '$_base/15-Ishiara12.webp',
        '$_base/16-Ishiara13.webp',
        '$_base/17-Ishiara14.webp',
        '$_base/18-Ishiara15.webp',
        '$_base/19-Ishiara16.webp',
        '$_base/20-Ishiara17.webp',
        '$_base/21-Ishiara18.webp',
        '$_base/22-Ishiara19.webp',
        '$_base/23-Ishiara20.webp',
        '$_base/24-Ishiara21.webp',
        '$_base/25-Ishiara22.webp',
        '$_base/26-Ishiara23.webp',
        '$_base/27-Ishiara24.webp',
      ],
      VisualHealthCategory.childrenBicromatic: [
        '$_base/vh_children_01.jpg',
        '$_base/vh_children_02.jpg',
        '$_base/vh_children_03.jpg',
        '$_base/vh_children_04.jpg',
        '$_base/vh_children_05.jpg',
      ],
      VisualHealthCategory.ametropia: [
        '$_base/vh_normal_vision.jpg',
        '$_base/vh_myopia.jpg',
        '$_base/vh_hyperopia.jpg',
        '$_base/vh_astigmatism.jpg',
        '$_base/vh_emmetropias.jpg',
        '$_base/vh_anatomy.jpg',
        '$_base/vh_muscles.jpg',
      ],
      VisualHealthCategory.pathologies: [
        '$_base/vh_cataract.jpg',
        '$_base/vh_macular_deg.jpg',
        '$_base/vh_retinal_det.jpg',
        '$_base/vh_squint.jpg',
        '$_base/vh_glaucoma.jpg',
        '$_base/vh_retinopathy.jpg',
      ],
      VisualHealthCategory.amsler: [
        '$_base/vh_amsler_black.jpg',
        '$_base/vh_amsler_white.jpg',
      ],
    };

    emit(state.copyWith(
      categoryImages: categoryImages,
      isInitialized: true,
      currentTestIndex: 0,
      selectedCategory: VisualHealthCategory.visionTests,
    ));
  }

  void selectCategory(VisualHealthCategory category) {
    emit(state.copyWith(selectedCategory: category, currentTestIndex: 0));
  }

  void selectTest(int index) {
    if (index >= 0 && index < state.testImages.length) {
      emit(state.copyWith(currentTestIndex: index));
    }
  }

  void nextTest() {
    if (state.currentTestIndex < state.testImages.length - 1) {
      emit(state.copyWith(currentTestIndex: state.currentTestIndex + 1));
    }
  }

  void previousTest() {
    if (state.currentTestIndex > 0) {
      emit(state.copyWith(currentTestIndex: state.currentTestIndex - 1));
    }
  }

  void reset() {
    emit(state.copyWith(currentTestIndex: 0));
  }
}
