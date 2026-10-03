import 'package:flutter/material.dart';
import '../core/colores.dart';
import '../core/modelos.dart';
import '../core/roles.dart';
import '../servicios/auth_servicio.dart';
import '../servicios/usuarios_servicio.dart';
import 'diagnostico_pantalla.dart';

class AdminPantalla extends StatefulWidget {
  const AdminPantalla({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<AdminPantalla> createState() => _AdminPantallaState();
}

class _AdminPantallaState extends State<AdminPantalla> {
  final _users = UsuariosServicio();
  final _auth = AuthServicio();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = Roles.docente;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 12) {
      setState(
        () => _message =
            'Completa nombre, correo y una contraseña temporal de al menos 12 caracteres.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _users.crearUsuario(
        nombre: _name.text.trim(),
        correo: _email.text.trim(),
        temporaryPassword: _password.text,
        role: _role,
      );
      _name.clear();
      _email.clear();
      _password.clear();
      if (mounted) {
        setState(
          () => _message = 'Usuario creado en Auth, claims y Firestore.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'No fue posible crear el usuario. Revisa los datos y permisos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Usuario user) async {
    final name = TextEditingController(text: user.nombre);
    var role = user.role;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: Roles.todos
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(Roles.etiqueta(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => role = value ?? role),
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      await _users.actualizarUsuario(
        uid: user.uid,
        nombre: name.text.trim(),
        role: role,
      );
    }
    name.dispose();
  }

  Future<void> _delete(Usuario user) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta completa'),
        content: Text(
          'Se eliminarán Auth, perfil e instalaciones de ${user.nombre}. Esta acción no se puede deshacer desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colores.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (accepted == true) await _users.eliminarUsuario(user.uid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colores.rojo,
      foregroundColor: Colors.white,
      title: const Text('CENTINELA · Administración'),
      actions: [
        IconButton(
          tooltip: 'Diagnóstico',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiagnosticoPantalla(usuario: widget.usuario),
            ),
          ),
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _auth.cerrarSesion,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crear usuario en ${widget.usuario.sedeId}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña temporal segura',
                    helperText: '12+ caracteres, mayúscula, minúscula y número',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: Roles.todos
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(Roles.etiqueta(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _role = value ?? _role),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(_message!),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: const Text('CREAR USUARIO'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Usuarios de la sede',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<List<Usuario>>(
          stream: _users.listaUsuarios(widget.usuario.sedeId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No se pudo cargar. Revisa el índice y los claims.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: snapshot.data!
                  .map(
                    (user) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.nombre.isEmpty
                                ? '?'
                                : user.nombre[0].toUpperCase(),
                          ),
                        ),
                        title: Text(user.nombre),
                        subtitle: Text(
                          '${user.correo}\n${Roles.etiqueta(user.role)} · ${user.active ? 'Activo' : 'Desactivado'}',
                        ),
                        isThreeLine: true,
                        onTap: () => _edit(user),
                        trailing: user.uid == widget.usuario.uid
                            ? const Icon(Icons.verified_user)
                            : PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'toggle') {
                                    await _users.establecerActivo(
                                      user.uid,
                                      !user.active,
                                    );
                                  }
                                  if (action == 'delete') await _delete(user);
                                  if (action == 'edit') await _edit(user);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      user.active ? 'Desactivar' : 'Reactivar',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
