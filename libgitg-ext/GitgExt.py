from gi.repository import GObject
from ..overrides import override
from ..importer import modules

GitgExt = modules['GitgExt']._introspection_module
__all__ = []

class MessageBus(GitgExt.MessageBus):
    def create(self, msgid, **kwargs):
        tp = self.lookup(msgid)

        if not tp.is_a(GitgExt.Message.__gtype__):
            return None

        kwargs['id'] = msgid

        return GObject.new(tp, **kwargs)

    def send(self, msgid, **kwargs):
        msg = self.create(msgid, **kwargs)
        self.send_message(msg)

        return msg

MessageBus = override(MessageBus)
__all__.append('MessageBus')

class Message(GitgExt.Message):
    def __getattribute__(self, name):
        try:
            return GitgExt.Message.__getattribute__(self, name)
        except:
            return getattr(self.props, name)

Message = override(Message)
__all__.append('Message')

# vi:ex:ts=4:et
