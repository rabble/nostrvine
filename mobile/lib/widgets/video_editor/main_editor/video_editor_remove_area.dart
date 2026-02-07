import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';

class VideoEditorRemoveArea extends ConsumerWidget {
  const VideoEditorRemoveArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLayerOverRemoveArea = context.select(
      (VideoEditorMainBloc bloc) => bloc.state.isLayerOverRemoveArea,
    );

    return Center(
      child: AnimatedScale(
        scale: isLayerOverRemoveArea ? 1.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          padding: const .all(10),
          decoration: ShapeDecoration(
            color: VineTheme.error,
            shape: RoundedRectangleBorder(borderRadius: .circular(20)),
          ),
          child: SizedBox(
            height: 28,
            width: 28,
            child: SvgPicture.asset(
              'assets/icon/delete.svg',
              colorFilter: const .mode(Color(0xFF000000), .srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
