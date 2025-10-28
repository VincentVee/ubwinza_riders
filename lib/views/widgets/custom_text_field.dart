import 'package:flutter/material.dart';

class CustomeTextField extends StatefulWidget {
  final TextEditingController? textEditingController;
  final IconData? iconData;
  final String? hintString;
  bool? isObsecure = true;
  bool? enable = true;
  final Widget? suffixIcon;

  CustomeTextField({
    super.key,
    this.textEditingController,
    this.iconData,
    this.hintString,
    this.isObsecure,
    this.enable,
    this.suffixIcon,
  });

  @override
  State<CustomeTextField> createState() => _CustomeTextFieldState();
}

class _CustomeTextFieldState extends State<CustomeTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.all(11),
      child: TextFormField(
        style: const TextStyle(color: Colors.black),
        enabled: widget.enable,
        controller: widget.textEditingController,
        obscureText: widget.isObsecure!,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: widget.iconData != null
              ? Icon(
            widget.iconData,
            color: Colors.blueAccent,
          )
              : null,
          hintText: widget.hintString,
          hintStyle: const TextStyle(color: Colors.grey),
          suffixIcon: widget.suffixIcon, // <-- added support here
        ),
      ),
    );
  }
}
