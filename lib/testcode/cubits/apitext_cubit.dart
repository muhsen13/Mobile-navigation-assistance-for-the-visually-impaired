import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:graduation_project/testcode/cubits/apitext_model.dart';

class ApitextCubit extends Cubit<ApitextModel>{

  ApitextCubit(super.initialState);


  void updateCordinates(double x,double y){
    state.cordinates = [x,y];
    emit(state);
  }
  void tempAddCordinates(double x,double y){
    state.cordinates.add(x);
    state.cordinates.add(y);
    emit(state);
  }
}