import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomLoadingAnimation extends StatelessWidget {
  final String message;
  const CustomLoadingAnimation({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                duration: 600.ms,
                delay: (200 * index).ms,
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.2, 1.2),
                curve: Curves.easeInOut,
              )
              .fade(begin: 0.5, end: 1.0);
            }),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: Colors.grey[600],
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ).animate().fadeIn(duration: 800.ms),
        ],
      ),
    );
  }
}

class CustomUploadingAnimation extends StatelessWidget {
  final String message;
  const CustomUploadingAnimation({super.key, this.message = 'Uploading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              spreadRadius: 4,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Stack(
               alignment: Alignment.center,
               children: [
                 // Orbiting particles
                 Container(
                   width: 80,
                   height: 80,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                       width: 2,
                     )
                   ),
                 ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),
                 
                 // Rotating ring
                 Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                         color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                         width: 3,
                      )
                    ),
                    child: const Icon(Icons.cloud_upload_outlined, size: 28),
                 ).animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1.5.seconds, color: Theme.of(context).primaryColor),
               ],
             ),
             const SizedBox(height: 24),
             Text(
               message,
               style: GoogleFonts.outfit(
                 fontWeight: FontWeight.bold,
                 fontSize: 16,
               ),
             ).animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.6, end: 1.0, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
